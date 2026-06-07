#!/usr/bin/env python3
"""Recursive disassembly tracer for DreamWriter ROM images.

Traces execution from seed entry points, following all near calls,
near branches, and far calls/jumps within known segments. Deduplicates
at the instruction level so no address is disassembled twice.

Usage:
    python3 tools/trace_boot.py [--rom PATH] [--seed SEG:OFF ...] [--irqs] [--thunks]
        [--int21] [--menu-vm] [--dispatch] [--load FILE]

Default seeds: C000:0029 (boot entry).
--irqs adds hardware IRQ entry points (NMI, keyboard, warm/power).
--thunks reads the banked thunk dispatch table at C000:1B38 and adds
each slot as a seed.
--menu-vm reads the C772 bytecode interpreter dispatch table at C772:396F
(96 entries) and adds each handler as a seed.
--dispatch reads all other known indirect-jump dispatch tables (AD00
ROM CARD ops, C000 display commands, C772 format/landing pads).
--load FILE reloads a previous trace output file to avoid re-tracing
unchanged blocks. Only new seeds are traced incrementally.
"""

from __future__ import annotations

import argparse
import re
import struct
import subprocess
import sys
from collections import OrderedDict
from dataclasses import dataclass, field


@dataclass
class Segment:
    name: str
    seg_value: int      # e.g. 0xC000
    file_base: int      # file offset of seg:0000
    max_offset: int     # highest valid offset in this segment
    covered: set = field(default_factory=set)

    def file_offset(self, off: int) -> int:
        return self.file_base + off

    def contains_phys(self, phys: int) -> bool:
        return self.file_base <= phys < self.file_base + self.max_offset


# Window 6 segments for v3.1 (1 MiB ROM, bank 14 at file 0xC0000)
WINDOW6_START = 0xC0000
WINDOW6_END = 0xE0000

SEGMENTS: dict[str, Segment] = {}


def add_segment(name: str, seg_value: int, max_offset: int):
    file_base = (seg_value << 4)
    SEGMENTS[name] = Segment(name, seg_value, file_base, max_offset)


def find_segment_for_far(seg_value: int, offset: int) -> tuple[str, int] | None:
    """Resolve a far seg:off using the transfer's segment value.

    If the segment value matches a registered segment, use it directly.
    Otherwise auto-register a new segment from the call's segment value
    so the trace reflects what CS the CPU actually has.
    """
    for seg in SEGMENTS.values():
        if seg.seg_value == seg_value:
            if 0 <= offset < seg.max_offset:
                return seg.name, offset
    phys = (seg_value << 4) + offset
    if phys >= len(ROM):
        return None
    # Check if another segment covers this physical address
    for seg in SEGMENTS.values():
        if seg.file_base <= phys < seg.file_base + seg.max_offset:
            other_off = phys - seg.file_base
            print(f"warning: far {seg_value:04X}:{offset:04X} (phys {phys:05X}) "
                  f"has no segment; overlaps {seg.name}:{other_off:04X}. "
                  f"Auto-creating segment {seg_value:04X}.",
                  file=sys.stderr)
            break
    name = f"{seg_value:04X}"
    max_off = len(ROM) - (seg_value << 4)
    if max_off <= 0:
        return None
    add_segment(name, seg_value, min(max_off, 0x10000))
    return name, offset


@dataclass
class Block:
    segment: str
    start: int
    end: int
    insns: list
    calls: list         # [(seg, off)]
    branches: list      # [(seg, off)]
    end_type: str
    label: str = ""


ROM: bytes = b""
BLOCKS: OrderedDict[tuple[str, int], Block] = OrderedDict()

# Addresses where the tracer should stop disassembling.
STOP_ADDRS: set[tuple[str, int]] = set()

# Call targets known to never return (JMP to event loop, etc.).
# Any CALL to one of these terminates the block.
NORETURN_CALLS: set[tuple[str, int]] = set()

COND_OPS = frozenset({
    "jz", "jnz", "jc", "jnc", "jb", "jnb", "ja", "jna",
    "jbe", "jnbe", "jae", "jnae", "jl", "jnl", "jg", "jng",
    "jle", "jnle", "jge", "jnge", "je", "jne", "js", "jns",
    "jo", "jno", "jp", "jnp", "jcxz", "loop", "loopz", "loopnz",
})


def parse_far_target(mnemonic: str) -> tuple[int, int] | None:
    """Extract seg:off from a far call/jmp mnemonic."""
    m = re.search(r'0x([0-9a-f]+):0x([0-9a-f]+)', mnemonic, re.I)
    if m:
        return int(m.group(1), 16), int(m.group(2), 16)
    return None


def disasm_block(seg_name: str, offset: int, max_bytes: int = 0x400) -> Block:
    seg = SEGMENTS[seg_name]
    file_off = seg.file_offset(offset)
    if file_off >= len(ROM) or offset >= seg.max_offset:
        return Block(seg_name, offset, offset, [], [], [], "eof")

    result = subprocess.run(
        ["ndisasm", "-b", "16", "-o", hex(offset),
         "-e", hex(file_off), "-"],
        input=ROM, capture_output=True, timeout=10,
    )

    insns = []
    calls = []
    branches = []
    end_type = "limit"

    for raw in result.stdout.decode().split("\n"):
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split(None, 2)
        if len(parts) < 2:
            continue
        try:
            addr = int(parts[0], 16)
        except ValueError:
            continue
        if addr < offset:
            continue
        if addr >= offset + max_bytes:
            break
        if addr in seg.covered:
            end_type = "already_covered"
            break
        if (seg_name, addr) in STOP_ADDRS:
            end_type = "blacklisted"
            break

        bytehex = parts[1]
        mnemonic = parts[2] if len(parts) > 2 else ""
        insn_len = len(bytehex) // 2
        insns.append((addr, bytehex, mnemonic, insn_len))

        mn = mnemonic.lower().strip()
        words = mn.split()
        if not words:
            continue
        op = words[0]

        # --- unconditional jump ---
        if op == "jmp":
            far = parse_far_target(mn)
            if far:
                far_seg, far_off = far
                resolved = find_segment_for_far(far_seg, far_off)
                if resolved:
                    branches.append(resolved)
                end_type = "jmp_far"
                break
            target_str = words[-1]
            if target_str.startswith("0x") and ":" not in target_str:
                try:
                    target = int(target_str, 16)
                    branches.append((seg_name, target))
                except ValueError:
                    pass
                end_type = "jmp"
                break
            end_type = "jmp_indirect"
            break

        # --- returns ---
        if op in ("ret", "retf", "iret"):
            end_type = op
            break
        if bytehex.lower() == "cf":
            end_type = "iret"
            break

        # --- near call ---
        if op == "call" and len(words) == 2:
            resolved_call = None
            w = words[1]
            if w.startswith("0x") and ":" not in w:
                try:
                    target = int(w, 16)
                    resolved_call = (seg_name, target)
                except ValueError:
                    pass
            elif ":" in mn:
                far = parse_far_target(mn)
                if far:
                    far_seg, far_off = far
                    resolved_call = find_segment_for_far(far_seg, far_off)
            if resolved_call:
                calls.append(resolved_call)
                if resolved_call in NORETURN_CALLS:
                    end_type = "call_noreturn"
                    break

        # --- conditional branch ---
        if op in COND_OPS:
            target_str = words[-1]
            if target_str.startswith("0x"):
                try:
                    target = int(target_str, 16)
                    branches.append((seg_name, target))
                except ValueError:
                    pass

    end = insns[-1][0] + insns[-1][3] if insns else offset
    return Block(seg_name, offset, end, insns, calls, branches, end_type)


def trace(seeds: list[tuple[str, int, str]], max_blocks: int = 5000):
    pending = list(seeds)
    count = 0

    while pending and count < max_blocks:
        seg_name, offset, label = pending.pop(0)
        seg = SEGMENTS.get(seg_name)
        if seg is None:
            continue
        if offset in seg.covered:
            continue
        if offset < 0 or offset >= seg.max_offset:
            continue

        # Warn if this physical address is already traced under a different segment
        phys = seg.file_offset(offset)
        for other_name, other_seg in SEGMENTS.items():
            if other_name == seg_name:
                continue
            other_off = phys - other_seg.file_base
            if 0 <= other_off < other_seg.max_offset and other_off in other_seg.covered:
                print(f"warning: {seg_name}:{offset:04X} (phys {phys:05X}) already "
                      f"traced as {other_name}:{other_off:04X}",
                      file=sys.stderr)
                break

        block = disasm_block(seg_name, offset)
        if not block.insns:
            continue

        # Mark all instruction addresses as covered
        for addr, _, _, insn_len in block.insns:
            for a in range(addr, addr + insn_len):
                seg.covered.add(a)

        block.label = label
        BLOCKS[(seg_name, offset)] = block
        count += 1

        for target_seg, target_off in block.branches:
            tseg = SEGMENTS.get(target_seg)
            if tseg and target_off not in tseg.covered:
                pending.append((target_seg, target_off, f"from_{seg_name}:{offset:04X}"))

        for target_seg, target_off in block.calls:
            tseg = SEGMENTS.get(target_seg)
            if tseg and target_off not in tseg.covered:
                pending.append((target_seg, target_off, f"call_{seg_name}:{offset:04X}"))


def output():
    for (seg_name, start) in sorted(BLOCKS.keys(), key=lambda k: (k[0], k[1])):
        block = BLOCKS[(seg_name, start)]
        if not block.insns:
            continue

        parts = [f"--- {seg_name}:{start:04X}..{block.end:04X}"]
        if block.label:
            parts.append(f"  ; {block.label}")

        call_strs = []
        for cs, co in block.calls:
            call_strs.append(f"{cs}:{co:04X}")
        if call_strs:
            parts.append(f"  calls:{','.join(call_strs)}")

        branch_strs = []
        for bs, bo in block.branches:
            branch_strs.append(f"{bs}:{bo:04X}")
        if branch_strs:
            parts.append(f"  branches:{','.join(branch_strs)}")

        print("".join(parts))
        for addr, bytehex, mnemonic, _ in block.insns:
            print(f"  {seg_name}:{addr:04X}  {bytehex:<14s} {mnemonic}")
        print(f"  ; end: {block.end_type}")
        print()


def read_thunk_table(table_offset: int = 0x1B38, count: int = 12) -> list[tuple[str, int, str]]:
    """Read the banked thunk dispatch table and return seed entries."""
    seeds = []
    for i in range(count):
        file_off = WINDOW6_START + table_offset + i * 2
        if file_off + 2 > len(ROM):
            break
        target = struct.unpack_from("<H", ROM, file_off)[0]
        if 0 < target < 0x20000:
            seeds.append(("C000", target, f"thunk_slot_{i}"))
    return seeds


def read_menu_vm_table(table_offset: int = 0x396F, count: int = 96) -> list[tuple[str, int, str]]:
    """Read the C772 menu VM bytecode dispatch table and return seed entries."""
    seg = SEGMENTS["C772"]
    seeds = []
    for i in range(count):
        file_off = seg.file_base + table_offset + i * 2
        if file_off + 2 > len(ROM):
            break
        target = struct.unpack_from("<H", ROM, file_off)[0]
        if 0 < target < seg.max_offset:
            bytecode = i * 2
            seeds.append(("C772", target, f"vm_op_{bytecode:02X}"))
    return seeds


def read_word_table(seg_name: str, table_offset: int, count: int,
                    label_prefix: str) -> list[tuple[str, int, str]]:
    """Read a word dispatch table from ROM and return seed entries."""
    seg = SEGMENTS[seg_name]
    seeds = []
    seen = set()
    for i in range(count):
        file_off = seg.file_base + table_offset + i * 2
        if file_off + 2 > len(ROM):
            break
        target = struct.unpack_from("<H", ROM, file_off)[0]
        if 0 < target < seg.max_offset and target not in seen:
            seen.add(target)
            seeds.append((seg_name, target, f"{label_prefix}_{i}"))
    return seeds


def read_dispatch_tables() -> list[tuple[str, int, str]]:
    """Read all known indirect-jump dispatch tables not covered by other flags."""
    seeds = []

    # AD00:0202 — ROM CARD operation dispatch (21 word entries)
    # Reached via AD00:01FD  jmp [cs:bx+0x202]
    seeds.extend(read_word_table("AD00", 0x0202, 21, "ad00_op"))

    # C000:6865 — display stream FF-command dispatch (32 word entries)
    # Reached via C000:6860  jmp [cs:si+0x6865]
    seeds.extend(read_word_table("C000", 0x6865, 32, "disp_cmd"))

    # C772:40ED — format sub-dispatch (7 word entries)
    # Reached via C772:3FA6  jmp dx  where dx = [cs:si], si = 0x40ED + (al-1)*2
    seeds.extend(read_word_table("C772", 0x40ED, 7, "fmt_op"))

    # C772:215F — computed-jump landing pad (JMP SHORT fan-out)
    # Reached via C772:215D  jmp si  where si = byte_index + 0x215F
    seeds.append(("C772", 0x215F, "landing_215F"))

    # C772:6BE3 — character class landing pad (JMP SHORT fan-out)
    # Reached via C772:6BE1  jmp si  where si = nibble*2 + 0x6BE3
    seeds.append(("C772", 0x6BE3, "landing_6BE3"))

    # C772:968A inline search table targets (CALL 968A pattern at 9638)
    # Table at 963B: match_byte, target_word triples
    seg = SEGMENTS["C772"]
    table_off = seg.file_base + 0x963B
    seen = set()
    i = 0
    while i < 30:
        match_byte = ROM[table_off + i]
        if match_byte == 0:
            break
        target = struct.unpack_from("<H", ROM, table_off + i + 1)[0]
        if 0 < target < seg.max_offset and target not in seen:
            seen.add(target)
            seeds.append(("C772", target, f"search_96_{match_byte:02X}"))
        i += 3

    return seeds


def load_trace(path: str) -> int:
    """Load a previous trace output file, reconstructing BLOCKS and covered sets."""
    header_re = re.compile(
        r'^--- ([A-Z0-9]+):([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+)(.*)')
    insn_re = re.compile(
        r'^\s+[A-Z0-9]+:([0-9A-Fa-f]+)\s+([0-9A-Fa-f]+)\s+(.*)')
    end_re = re.compile(r'^\s+; end:\s+(\S+)')

    cur_seg = None
    cur_start = 0
    cur_end = 0
    cur_label = ""
    cur_calls = []
    cur_branches = []
    cur_insns = []
    cur_end_type = ""
    in_block = False
    loaded = 0

    def parse_targets(s: str) -> list[tuple[str, int]]:
        result = []
        for item in s.split(","):
            item = item.strip()
            if ":" in item:
                seg_str, off_str = item.split(":", 1)
                try:
                    result.append((seg_str, int(off_str, 16)))
                except ValueError:
                    pass
        return result

    def finalize():
        nonlocal loaded, in_block
        if not cur_insns:
            in_block = False
            return
        seg = SEGMENTS.get(cur_seg)
        if seg is None:
            print(f"warning: unknown segment '{cur_seg}' in loaded trace, skipping",
                  file=sys.stderr)
            in_block = False
            return
        block = Block(cur_seg, cur_start, cur_end, list(cur_insns),
                      list(cur_calls), list(cur_branches), cur_end_type, cur_label)
        BLOCKS[(cur_seg, cur_start)] = block
        for addr, _, _, insn_len in cur_insns:
            for a in range(addr, addr + insn_len):
                seg.covered.add(a)
        loaded += 1
        in_block = False

    with open(path) as f:
        for line in f:
            line = line.rstrip("\n")

            m = header_re.match(line)
            if m:
                if in_block:
                    finalize()
                cur_seg = m.group(1)
                cur_start = int(m.group(2), 16)
                cur_end = int(m.group(3), 16)
                remainder = m.group(4)
                cur_label = ""
                cur_calls = []
                cur_branches = []
                cur_insns = []
                cur_end_type = ""
                in_block = True

                lm = re.search(r";\s+(\S+)", remainder)
                if lm:
                    cur_label = lm.group(1)
                cm = re.search(r"calls:(\S+)", remainder)
                if cm:
                    cur_calls = parse_targets(cm.group(1))
                bm = re.search(r"branches:(\S+)", remainder)
                if bm:
                    cur_branches = parse_targets(bm.group(1))
                continue

            if in_block:
                em = end_re.match(line)
                if em:
                    cur_end_type = em.group(1)
                    continue
                im = insn_re.match(line)
                if im:
                    addr = int(im.group(1), 16)
                    bytehex = im.group(2)
                    mnemonic = im.group(3).rstrip()
                    insn_len = len(bytehex) // 2
                    cur_insns.append((addr, bytehex, mnemonic, insn_len))
                    continue
                if not line.strip():
                    finalize()

    if in_block:
        finalize()

    return loaded


def main():
    global ROM

    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rom", type=str, default="v3.1/t4_ir_3.1_e588.ic303")
    parser.add_argument("--seed", action="append", default=[], metavar="SEG:OFF",
                        help="Additional seed entry point (e.g. C000:0029)")
    parser.add_argument("--irqs", action="store_true",
                        help="Add hardware IRQ entry points as seeds")
    parser.add_argument("--thunks", action="store_true",
                        help="Add banked thunk dispatch table entries as seeds")
    parser.add_argument("--int21", action="store_true",
                        help="Add INT 21h handler dispatch table entries as seeds")
    parser.add_argument("--menu-vm", action="store_true",
                        help="Add C772 menu VM bytecode handler dispatch table entries as seeds")
    parser.add_argument("--dispatch", action="store_true",
                        help="Add all other known indirect-jump dispatch table entries as seeds")
    parser.add_argument("--load", type=str, metavar="FILE",
                        help="Load previous trace output to resume from")
    parser.add_argument("--max-blocks", type=int, default=5000)
    parser.add_argument("--stop", action="append", default=[], metavar="SEG:OFF",
                        help="Blacklist address: stop tracing if reached (e.g. C772:40C1)")
    args = parser.parse_args()

    ROM = open(args.rom, "rb").read()

    # Set up segments for window 6 (port 0x16=0x01, bank 14, file 0xC0000)
    add_segment("C000", 0xC000, 0x10000)     # C000:0000..FFFF
    add_segment("C772", 0xC772, 0x188E0)     # C772:0000 to end of window
    add_segment("DEF0", 0xDEF0, 0x10F00)     # DEF0:0000 to end of window

    # Window 5 (port 0x15=0x02 during banked call, bank 13, file 0xA0000)
    add_segment("AD00", 0xAD00, 0x13000)     # AD00:0000 to end of window

    # Window 7 (port 0x17=0x00, bank 15, file 0xE0000) — fixed, not banked
    add_segment("ED1B", 0xED1B, 0x12E50)     # ED1B:0000 to end of window
    add_segment("EE17", 0xEE17, 0x11E90)     # EE17:0000 to end of window

    # Default seeds
    seeds: list[tuple[str, int, str]] = [("C000", 0x0029, "boot_entry")]

    # Parse --seed arguments
    for s in args.seed:
        m = re.match(r"([0-9A-Fa-f]+):([0-9A-Fa-f]+)$", s)
        if m:
            seg_str = m.group(1).upper()
            off = int(m.group(2), 16)
            # Find or create segment
            seg_name = None
            for name, seg in SEGMENTS.items():
                if seg.seg_value == int(seg_str, 16):
                    seg_name = name
                    break
            if seg_name is None:
                seg_val = int(seg_str, 16)
                seg_name = seg_str
                add_segment(seg_name, seg_val, 0x10000)
            seeds.append((seg_name, off, f"seed_{s}"))
        else:
            print(f"warning: ignoring unparseable seed '{s}'", file=sys.stderr)

    # Parse --stop arguments
    for s in args.stop:
        m = re.match(r"([0-9A-Fa-f]+):([0-9A-Fa-f]+)$", s)
        if m:
            seg_str = m.group(1).upper()
            off = int(m.group(2), 16)
            for name, seg in SEGMENTS.items():
                if seg.seg_value == int(seg_str, 16):
                    STOP_ADDRS.add((name, off))
                    break

    # C772:022D is a dispatch entry (JMP 3944) used as an inline-data call.
    # Callers do "CALL 022D" followed by inline parameter bytes, not code.
    # The handler reads the data from the return address on the stack.
    # Auto-blacklist every address following a "CALL 022D" in the C772 segment.
    INLINE_DATA_CALLS = {("C772", 0x022D), ("C772", 0x968A), ("C772", 0x968D)}
    for seg_name, call_target in INLINE_DATA_CALLS:
        seg = SEGMENTS.get(seg_name)
        if seg is None:
            continue
        call_bytes = struct.pack("<BH", 0xE8, (call_target - 3) & 0xFFFF)  # placeholder
        # Scan the ROM for "E8 xx xx" where target resolves to call_target
        for off in range(0, seg.max_offset - 2):
            file_pos = seg.file_base + off
            if file_pos + 3 > len(ROM):
                break
            if ROM[file_pos] == 0xE8:
                rel = struct.unpack_from("<h", ROM, file_pos + 1)[0]
                target = (off + 3 + rel) & 0xFFFF
                if target == call_target:
                    stop_at = off + 3
                    STOP_ADDRS.add((seg_name, stop_at))

    # ED1B: city database and padding regions reached via fake branches
    STOP_ADDRS.add(("ED1B", 0x959E))
    STOP_ADDRS.add(("ED1B", 0x99B4))
    STOP_ADDRS.add(("ED1B", 0xA948))

    if args.irqs:
        irq_seeds = [
            # Explicit IVT vectors (installed by C000:1161)
            ("C000", 0x1832, "int_01h_debug"),
            ("C000", 0x04D0, "int_02h_nmi"),
            # Hardware IRQs F8-FF
            ("C000", 0x04D0, "irq_f8_nmi"),
            ("C000", 0x05C0, "irq_f9"),
            ("C000", 0x05D4, "irq_fa"),
            ("C000", 0x05F7, "irq_fb_keyboard"),
            ("C000", 0x0676, "irq_fc"),
            ("C000", 0x084A, "irq_fd"),
            ("C000", 0x085E, "irq_fe"),
            ("C000", 0x03FC, "irq_ff_warm"),
        ]
        seeds.extend(irq_seeds)

    if args.thunks:
        seeds.extend(read_thunk_table())

    if args.int21:
        # INT 21h validity table at C000:61DF maps AH (0..5F) to slot index.
        # Dispatch table at C000:623F has word entries indexed by slot.
        validity_off = 0xC0000 + 0x61DF
        dispatch_off = 0xC0000 + 0x623F
        dos_names = {
            0x03: "aux_input", 0x04: "aux_output", 0x05: "printer_output",
            0x08: "char_input", 0x0B: "input_status", 0x0E: "select_disk",
            0x19: "get_disk", 0x1A: "set_dta", 0x2A: "get_date",
            0x2B: "set_date", 0x2C: "get_time", 0x2D: "set_time",
            0x2F: "get_dta", 0x36: "disk_free", 0x3C: "create_file",
            0x3D: "open_file", 0x3E: "close_file", 0x3F: "read_file",
            0x40: "write_file", 0x41: "delete_file", 0x42: "seek",
            0x43: "get_set_attrs", 0x44: "ioctl", 0x4E: "find_first",
            0x4F: "find_next", 0x56: "rename", 0x57: "get_set_date",
            0x5B: "create_new",
        }
        seen_handlers = set()
        for ah in range(0x60):
            if validity_off + ah >= len(ROM):
                break
            slot = ROM[validity_off + ah]
            if slot == 0xFF:
                continue
            handler_off = dispatch_off + slot * 2
            if handler_off + 2 > len(ROM):
                continue
            handler = struct.unpack_from("<H", ROM, handler_off)[0]
            if handler not in seen_handlers and 0 < handler < 0x10000:
                seen_handlers.add(handler)
                name = dos_names.get(ah, f"ah_{ah:02x}")
                seeds.append(("C000", handler, f"int21_{name}"))
                # If the handler is a CALL+RET stub, also seed the call target
                stub_off = 0xC0000 + handler
                if stub_off + 3 <= len(ROM) and ROM[stub_off] == 0xE8:
                    rel = struct.unpack_from("<h", ROM, stub_off + 1)[0]
                    target = (handler + 3 + rel) & 0xFFFF
                    if target not in seen_handlers:
                        seen_handlers.add(target)
                        seeds.append(("C000", target, f"int21_{name}_impl"))

    if args.menu_vm:
        seeds.extend(read_menu_vm_table())

    if args.dispatch:
        seeds.extend(read_dispatch_tables())

    loaded = 0
    if args.load:
        loaded = load_trace(args.load)
        print(f"Loaded {loaded} blocks from {args.load}", file=sys.stderr)

    trace(seeds, args.max_blocks)

    total_insns = sum(len(b.insns) for b in BLOCKS.values())
    seg_counts = {}
    for (sn, _), b in BLOCKS.items():
        seg_counts[sn] = seg_counts.get(sn, 0) + 1
    seg_summary = ", ".join(f"{n}:{c}" for n, c in sorted(seg_counts.items()))
    new_blocks = len(BLOCKS) - loaded
    if loaded:
        print(f"Traced {len(BLOCKS)} blocks ({new_blocks} new), {total_insns} instructions ({seg_summary})",
              file=sys.stderr)
    else:
        print(f"Traced {len(BLOCKS)} blocks, {total_insns} instructions ({seg_summary})",
              file=sys.stderr)

    output()


if __name__ == "__main__":
    main()

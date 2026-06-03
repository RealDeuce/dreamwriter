#!/usr/bin/env python3
"""Audit and generate reference artifacts for disassembly markdown."""

from __future__ import annotations

import argparse
import html
import re
import struct
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

from rom2 import expand_markdown_inputs, parse_addr_expr, phys_to_file


DOC_GLOBS = ["docs/disassembly/*.md"]
OUTPUTS = {
    "assets": Path("docs/disassembly/asset-index.md"),
    "strings": Path("docs/disassembly/string-resource-index.md"),
    "ram": Path("docs/disassembly/ram-ledger.md"),
    "io": Path("docs/disassembly/io-port-ledger.md"),
    "transfers": Path("docs/disassembly/transfer-targets.md"),
    "graph": Path("docs/disassembly/call-graph.dot"),
}
GENERATED_NAMES = {path.name for path in OUTPUTS.values()} | {"symbol-index.html"}

ASM_START_RE = re.compile(r"^```asm\s*$")
FENCE_RE = re.compile(r"^```\s*$")
FILE_COMMENT_RE = re.compile(r";\s*file\s+0x([0-9A-Fa-f]+)")
INSTR_RE = re.compile(
    r"^(?P<addr>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\s+"
    r"(?P<bytes>(?:[0-9A-Fa-f]{2,})(?:\s+[0-9A-Fa-f]{2,})*)\s+(?P<rest>.*)$"
)
LABEL_RE = re.compile(r"^(?P<name>[A-Za-z_.$][A-Za-z0-9_.$-]*):\s*$")
LABEL_ADDR_RE = re.compile(r"_(?P<seg>[0-9A-Fa-f]{4})_(?P<off>[0-9A-Fa-f]{4})$")
TRANSFER_RE = re.compile(r"^(?P<kind>call|j[a-z]+|loop)\s+(?P<target>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\b", re.I)
RAM_REF_RE = re.compile(r"\[(?:0x)?(?P<addr>[0-9A-Fa-f]{3,4})\]")
PORT_RE = re.compile(r"\b(?:port\s+`?0x|(?:in|out)\s+(?:al|ax|dx)?\s*,?\s*0x)(?P<port>[0-9A-Fa-f]{2,4})", re.I)
IMAGE_RE = re.compile(r"!\[[^\]]*\]\((?P<path>images/[^)]+\.png)\)")
FILE_RE = re.compile(r"`?file\s+0x(?P<off>[0-9A-Fa-f]+)`?", re.I)
DIM_RE = re.compile(r"(?<![A-Za-z0-9])`?(?P<w>\d+)x(?P<h>\d+)`?(?![A-Za-z0-9])")
ROW_BYTES_RE = re.compile(r"row bytes\s+`?(?P<row>[0-9A-Fa-fx]+)`?", re.I)


@dataclass(frozen=True)
class SourceLine:
    path: Path
    line_no: int
    text: str
    in_asm: bool


@dataclass(frozen=True)
class Symbol:
    address: str
    name: str
    path: Path
    line_no: int


@dataclass(frozen=True)
class Instruction:
    address: str
    rest: str
    path: Path
    line_no: int


@dataclass(frozen=True)
class Transfer:
    kind: str
    source: str
    target: str
    path: Path
    line_no: int


def docs_from_args(values: list[str] | None) -> list[Path]:
    docs = expand_markdown_inputs(values or DOC_GLOBS)
    return [path for path in docs if path.name not in GENERATED_NAMES and path.name != "README.md" and path.suffix == ".md"]


def iter_lines(paths: list[Path]) -> list[SourceLine]:
    lines: list[SourceLine] = []
    for path in paths:
        in_asm = False
        for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if ASM_START_RE.match(raw):
                in_asm = True
                lines.append(SourceLine(path, line_no, raw, in_asm))
                continue
            if in_asm and FENCE_RE.match(raw):
                lines.append(SourceLine(path, line_no, raw, in_asm))
                in_asm = False
                continue
            lines.append(SourceLine(path, line_no, raw, in_asm))
    return lines


def split_table_row(line: str) -> list[str] | None:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return None
    return [cell.strip() for cell in stripped.strip("|").split("|")]


def markdown_link(path: Path, line_no: int) -> str:
    return f"[{path.name}:{line_no}]({path.name}#L{line_no})"


def normalize_addr(addr: str) -> str:
    seg, off = addr.split(":")
    return f"{seg.upper()}:{off.upper()}"


def addr_sort(addr: str) -> tuple[int, int]:
    seg, off = addr.split(":")
    return int(seg, 16), int(off, 16)


def collect_instructions(lines: list[SourceLine]) -> list[Instruction]:
    out = []
    for line in lines:
        if not line.in_asm:
            continue
        match = INSTR_RE.match(line.text)
        if not match:
            continue
        rest = match.group("rest").split(";", 1)[0].strip()
        if rest.startswith("..."):
            continue
        out.append(Instruction(normalize_addr(match.group("addr")), rest, line.path, line.line_no))
    return out


def next_instruction(lines: list[str], start: int) -> str | None:
    for raw in lines[start + 1 : min(start + 8, len(lines))]:
        match = INSTR_RE.match(raw)
        if match:
            return normalize_addr(match.group("addr"))
        if raw.strip() and not raw.startswith(";") and not LABEL_RE.match(raw):
            # Allow file-offset comments and blank/comment lines between label
            # and instruction; stop at unrelated prose.
            if not FILE_COMMENT_RE.search(raw):
                break
    return None


def collect_symbols(paths: list[Path]) -> list[Symbol]:
    symbols: list[Symbol] = []
    for path in paths:
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        for idx, raw in enumerate(raw_lines):
            match = LABEL_RE.match(raw)
            if not match:
                continue
            name = match.group("name")
            suffix = LABEL_ADDR_RE.search(name)
            if suffix:
                address = f"{suffix.group('seg').upper()}:{suffix.group('off').upper()}"
            else:
                address = next_instruction(raw_lines, idx)
            if address:
                symbols.append(Symbol(address, name, path, idx + 1))
    return sorted(symbols, key=lambda item: (addr_sort(item.address), item.name.lower(), str(item.path)))


def collect_transfers(instructions: list[Instruction]) -> list[Transfer]:
    transfers: list[Transfer] = []
    for inst in instructions:
        match = TRANSFER_RE.match(inst.rest)
        if not match:
            continue
        transfers.append(
            Transfer(
                kind=match.group("kind").lower(),
                source=inst.address,
                target=normalize_addr(match.group("target")),
                path=inst.path,
                line_no=inst.line_no,
            )
        )
    return transfers


def check_file_comments(lines: list[SourceLine]) -> list[str]:
    errors: list[str] = []
    current_file: tuple[Path, int, int] | None = None
    previous_label: tuple[Path, int, str] | None = None
    saw_ellipsis = False
    for line in lines:
        if not line.in_asm:
            continue
        label_match = LABEL_RE.match(line.text)
        if label_match:
            previous_label = (line.path, line.line_no, label_match.group("name"))
            continue
        file_match = FILE_COMMENT_RE.search(line.text)
        if file_match:
            current_file = (line.path, line.line_no, int(file_match.group(1), 16))
            saw_ellipsis = False
            if previous_label is not None:
                suffix = LABEL_ADDR_RE.search(previous_label[2])
                if suffix:
                    label_addr = f"{suffix.group('seg').upper()}:{suffix.group('off').upper()}"
                    try:
                        _, phys = parse_addr_expr(label_addr)
                        if phys_to_file(phys) == int(file_match.group(1), 16):
                            current_file = None
                    except ValueError:
                        current_file = None
            continue
        if current_file is not None and "..." in line.text:
            saw_ellipsis = True
            continue
        inst_match = INSTR_RE.match(line.text)
        if not inst_match or current_file is None:
            continue
        if saw_ellipsis:
            current_file = None
            continue
        comment_path, comment_line, expected = current_file
        try:
            _, phys = parse_addr_expr(inst_match.group("addr"))
            actual = phys_to_file(phys)
        except ValueError as exc:
            current_file = None
            continue
        if actual != expected:
            errors.append(
                f"{comment_path}:{comment_line}: file comment 0x{expected:05X} "
                f"does not match next instruction {inst_match.group('addr')} file 0x{actual:05X}"
            )
        current_file = None
    return errors


def check_label_addresses(paths: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in paths:
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        for idx, raw in enumerate(raw_lines):
            label_match = LABEL_RE.match(raw)
            if not label_match:
                continue
            name = label_match.group("name")
            if name.startswith("."):
                continue
            suffix = LABEL_ADDR_RE.search(name)
            if not suffix:
                continue
            expected = f"{suffix.group('seg').upper()}:{suffix.group('off').upper()}"
            actual = next_instruction(raw_lines, idx)
            if actual is None:
                continue
            if actual != expected:
                exp_seg, exp_off = addr_sort(expected)
                act_seg, act_off = addr_sort(actual)
                if exp_seg == act_seg and abs(act_off - exp_off) <= 0x20:
                    continue
                errors.append(f"{path}:{idx + 1}: label {name} implies {expected}, next instruction is {actual}")
    return errors


def png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    return struct.unpack(">II", data[16:24])


def declared_asset_dimensions(line: str) -> tuple[int, int] | None:
    dims = [
        match for match in DIM_RE.finditer(line)
        if int(match.group("w")) > 0 and int(match.group("h")) > 0
    ]
    if not dims:
        return None
    # Prefer the last dimension in the descriptor; rows such as "four contiguous
    # 8x8 glyphs rendered as 8x32" should validate against the rendered size.
    match = dims[-1]
    return int(match.group("w")), int(match.group("h"))


def dimensions_compatible(declared: tuple[int, int], actual: tuple[int, int]) -> bool:
    dw, dh = declared
    aw, ah = actual
    if (dw, dh) == (aw, ah):
        return True
    if dw <= 0 or dh <= 0:
        return False
    return aw % dw == 0 and ah % dh == 0 and aw // dw == ah // dh


def collect_assets(lines: list[SourceLine]) -> list[dict[str, object]]:
    assets: list[dict[str, object]] = []
    for line in lines:
        for image in IMAGE_RE.finditer(line.text):
            image_path = Path("docs/disassembly") / image.group("path")
            before_files = list(FILE_RE.finditer(line.text[: image.start()]))
            after_files = list(FILE_RE.finditer(line.text[image.end() :]))
            file_match = before_files[-1] if before_files else (after_files[0] if after_files else None)
            dimensions = declared_asset_dimensions(line.text)
            row_match = ROW_BYTES_RE.search(line.text)
            assets.append(
                {
                    "path": image_path,
                    "relative": image.group("path"),
                    "file": int(file_match.group("off"), 16) if file_match else None,
                    "declared": dimensions,
                    "row_bytes": row_match.group("row") if row_match else "",
                    "source": line.path,
                    "line": line.line_no,
                }
            )
    return assets


def check_assets(assets: list[dict[str, object]]) -> list[str]:
    errors: list[str] = []
    for asset in assets:
        path = asset["path"]
        assert isinstance(path, Path)
        if not path.exists():
            errors.append(f"{asset['source']}:{asset['line']}: missing image {asset['relative']}")
            continue
        declared = asset["declared"]
        if declared is None:
            continue
        try:
            actual = png_dimensions(path)
        except ValueError as exc:
            errors.append(f"{path}: {exc}")
            continue
        if not dimensions_compatible(declared, actual):
            errors.append(
                f"{asset['source']}:{asset['line']}: image {asset['relative']} "
                f"declares {declared[0]}x{declared[1]} but PNG is {actual[0]}x{actual[1]}"
            )
    return errors


def collect_string_rows(paths: list[Path]) -> list[dict[str, object]]:
    wanted = {"final formatted text", "final value", "display text", "decoded text", "decoded final string", "final text/role"}
    rows: list[dict[str, object]] = []
    for path in paths:
        raw_lines = path.read_text(encoding="utf-8").splitlines()
        idx = 0
        while idx < len(raw_lines):
            header = split_table_row(raw_lines[idx])
            if not header:
                idx += 1
                continue
            if idx + 1 >= len(raw_lines) or not re.match(r"^\s*\|[-: |]+\|\s*$", raw_lines[idx + 1]):
                idx += 1
                continue
            lowered = [cell.lower() for cell in header]
            final_indexes = [i for i, cell in enumerate(lowered) if cell in wanted or "final formatted text" in cell]
            if not final_indexes:
                idx += 1
                continue
            final_idx = final_indexes[-1]
            descriptor_idx = next((i for i, cell in enumerate(lowered) if "descriptor" in cell or "payload" in cell), None)
            resource_idx = 0
            idx += 2
            while idx < len(raw_lines):
                cells = split_table_row(raw_lines[idx])
                if not cells or len(cells) < len(header):
                    break
                final = cells[final_idx].strip()
                if final:
                    rows.append(
                        {
                            "resource": cells[resource_idx],
                            "descriptor": cells[descriptor_idx] if descriptor_idx is not None and descriptor_idx < len(cells) else "",
                            "final": final,
                            "source": path,
                            "line": idx + 1,
                        }
                    )
                idx += 1
            continue
        # Include common "Final formatted text:" fenced blocks as manual rows.
        for line_no, raw in enumerate(raw_lines, 1):
            if raw.strip().lower().startswith("final formatted text"):
                rows.append({"resource": "(block)", "descriptor": "", "final": "(see source block)", "source": path, "line": line_no})
    return rows


def check_strings(rows: list[dict[str, object]]) -> list[str]:
    errors = []
    for row in rows:
        if not str(row["final"]).strip():
            errors.append(f"{row['source']}:{row['line']}: empty final string resource cell")
    return errors


def collect_ram_refs(lines: list[SourceLine]) -> dict[str, list[SourceLine]]:
    refs: dict[str, list[SourceLine]] = defaultdict(list)
    for line in lines:
        for match in RAM_REF_RE.finditer(line.text):
            addr = int(match.group("addr"), 16)
            if 0 <= addr <= 0xFFFF:
                refs[f"{addr:04X}"].append(line)
    return refs


def collect_ports(lines: list[SourceLine]) -> dict[str, list[SourceLine]]:
    refs: dict[str, list[SourceLine]] = defaultdict(list)
    for line in lines:
        for match in PORT_RE.finditer(line.text):
            port = int(match.group("port"), 16)
            refs[f"0x{port:02X}"].append(line)
    return refs


def context(text: str, limit: int = 110) -> str:
    clean = " ".join(text.strip().split())
    if len(clean) > limit:
        clean = clean[: limit - 3] + "..."
    return clean.replace("|", "\\|")


def render_asset_index(assets: list[dict[str, object]]) -> str:
    rows = [
        "# Asset Index",
        "",
        "Generated from image descriptors in the disassembly notes.",
        "",
        "| PNG | ROM file | Declared size | PNG size | Row bytes | Source |",
        "| --- | ---: | ---: | ---: | ---: | --- |",
    ]
    for asset in sorted(assets, key=lambda item: (str(item["relative"]), str(item["source"]), int(item["line"]))):
        path = asset["path"]
        assert isinstance(path, Path)
        actual = png_dimensions(path) if path.exists() else ("?", "?")
        declared = asset["declared"]
        declared_text = f"{declared[0]}x{declared[1]}" if declared else ""
        file_text = f"0x{asset['file']:05X}" if isinstance(asset["file"], int) else ""
        rows.append(
            f"| `{asset['relative']}` | `{file_text}` | `{declared_text}` | "
            f"`{actual[0]}x{actual[1]}` | `{asset['row_bytes']}` | {markdown_link(asset['source'], int(asset['line']))} |"
        )
    return "\n".join(rows) + "\n"


def render_string_index(rows_in: list[dict[str, object]]) -> str:
    rows = [
        "# String Resource Index",
        "",
        "Generated from documented string-resource tables and final formatted text blocks.",
        "",
        "| Resource | Descriptor | Final text | Source |",
        "| --- | --- | --- | --- |",
    ]
    for row in sorted(rows_in, key=lambda item: (str(item["source"]), int(item["line"]))):
        rows.append(
            f"| {context(str(row['resource']), 60)} | {context(str(row['descriptor']), 90)} | "
            f"{context(str(row['final']), 100)} | {markdown_link(row['source'], int(row['line']))} |"
        )
    return "\n".join(rows) + "\n"


def render_ref_ledger(title: str, intro: str, refs: dict[str, list[SourceLine]], key_label: str) -> str:
    rows = [
        f"# {title}",
        "",
        intro,
        "",
        f"| {key_label} | References | Sample contexts |",
        "| ---: | ---: | --- |",
    ]
    for key in sorted(refs, key=lambda value: int(value.replace("0x", ""), 16)):
        unique_sources = []
        seen = set()
        for line in refs[key]:
            source = markdown_link(line.path, line.line_no)
            if source not in seen:
                unique_sources.append(source)
                seen.add(source)
            if len(unique_sources) >= 6:
                break
        samples = []
        seen_context = set()
        for line in refs[key]:
            sample = context(line.text, 95)
            if sample not in seen_context:
                samples.append(sample)
                seen_context.add(sample)
            if len(samples) >= 3:
                break
        rows.append(f"| `{key}` | {len(refs[key])} | {'<br>'.join(unique_sources)}<br>{'<br>'.join(samples)} |")
    return "\n".join(rows) + "\n"


def render_transfer_targets(transfers: list[Transfer], symbols: list[Symbol]) -> str:
    symbol_by_addr: dict[str, list[Symbol]] = defaultdict(list)
    for symbol in symbols:
        symbol_by_addr[symbol.address].append(symbol)
    by_target: dict[str, list[Transfer]] = defaultdict(list)
    for transfer in transfers:
        by_target[transfer.target].append(transfer)
    rows = [
        "# Transfer Target Audit",
        "",
        "Generated from direct call/jump operands in annotated snippets. Address-only targets are not automatically wrong; they are review candidates.",
        "",
        "| Target | Symbol(s) | Transfers | Sample sources |",
        "| ---: | --- | ---: | --- |",
    ]
    for target in sorted(by_target, key=addr_sort):
        names = ", ".join(f"`{symbol.name}`" for symbol in symbol_by_addr.get(target, []))
        samples = []
        for transfer in by_target[target][:6]:
            samples.append(f"{transfer.kind} from `{transfer.source}` {markdown_link(transfer.path, transfer.line_no)}")
        rows.append(f"| `{target}` | {names or '(address-only)'} | {len(by_target[target])} | {'<br>'.join(samples)} |")
    return "\n".join(rows) + "\n"


def dot_id(value: str) -> str:
    return "n_" + re.sub(r"[^A-Za-z0-9_]", "_", value)


def render_call_graph(transfers: list[Transfer], symbols: list[Symbol]) -> str:
    symbol_by_addr: dict[str, str] = {}
    for symbol in symbols:
        symbol_by_addr.setdefault(symbol.address, symbol.name)
    edges = sorted({(transfer.source, transfer.target, transfer.kind) for transfer in transfers})
    lines = [
        "digraph disassembly_transfers {",
        "  graph [rankdir=LR];",
        "  node [shape=box, fontname=\"Courier\"];",
    ]
    nodes = sorted({node for edge in edges for node in edge[:2]}, key=addr_sort)
    for node in nodes:
        label = symbol_by_addr.get(node, node)
        lines.append(f"  {dot_id(node)} [label=\"{html.escape(label)}\\n{node}\"];")
    for source, target, kind in edges:
        lines.append(f"  {dot_id(source)} -> {dot_id(target)} [label=\"{kind}\"];")
    lines.append("}")
    return "\n".join(lines) + "\n"


def generated_contents(paths: list[Path]) -> dict[Path, str]:
    lines = iter_lines(paths)
    instructions = collect_instructions(lines)
    symbols = collect_symbols(paths)
    transfers = collect_transfers(instructions)
    assets = collect_assets(lines)
    strings = collect_string_rows(paths)
    ram_refs = collect_ram_refs(lines)
    ports = collect_ports(lines)
    return {
        OUTPUTS["assets"]: render_asset_index(assets),
        OUTPUTS["strings"]: render_string_index(strings),
        OUTPUTS["ram"]: render_ref_ledger("RAM Reference Ledger", "Generated from bracketed RAM references in disassembly notes.", ram_refs, "RAM"),
        OUTPUTS["io"]: render_ref_ledger("I/O Port Ledger", "Generated from port references in prose and annotated I/O instructions.", ports, "Port"),
        OUTPUTS["transfers"]: render_transfer_targets(transfers, symbols),
        OUTPUTS["graph"]: render_call_graph(transfers, symbols),
    }


def run_checks(paths: list[Path]) -> list[str]:
    lines = iter_lines(paths)
    errors: list[str] = []
    errors.extend(check_file_comments(lines))
    errors.extend(check_label_addresses(paths))
    assets = collect_assets(lines)
    errors.extend(check_assets(assets))
    errors.extend(check_strings(collect_string_rows(paths)))
    return errors


def cmd_check(args: argparse.Namespace) -> int:
    paths = docs_from_args(args.docs)
    errors = run_checks(paths)
    if args.generated:
        for output, content in generated_contents(paths).items():
            try:
                old = output.read_text(encoding="utf-8")
            except FileNotFoundError:
                errors.append(f"{output}: missing; regenerate with tools/disassembly_audit.py generate")
                continue
            if old != content:
                errors.append(f"{output}: stale; regenerate with tools/disassembly_audit.py generate")
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"disassembly audit: FAIL ({len(errors)} issues)", file=sys.stderr)
        return 1
    print("disassembly audit: PASS")
    return 0


def cmd_generate(args: argparse.Namespace) -> int:
    paths = docs_from_args(args.docs)
    for output, content in generated_contents(paths).items():
        output.write_text(content, encoding="utf-8")
        print(output)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    check = sub.add_parser("check", help="run semantic consistency checks")
    check.add_argument("--docs", action="append", help="markdown glob to scan; repeatable")
    check.add_argument("--generated", action="store_true", help="also require generated artifacts to be fresh")
    check.set_defaults(func=cmd_check)
    generate = sub.add_parser("generate", help="write generated audit artifacts")
    generate.add_argument("--docs", action="append", help="markdown glob to scan; repeatable")
    generate.set_defaults(func=cmd_generate)
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())

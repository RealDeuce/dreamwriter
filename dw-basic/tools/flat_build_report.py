#!/usr/bin/env python3
"""Report flat DW-BASIC linked size and large static reservations."""

from __future__ import annotations

import argparse
import ast
import operator
import re
from dataclasses import dataclass
from pathlib import Path


OBJECT_RE = re.compile(
    r"^\[([0-9A-Fa-f]+)\]\s+([^:]+):.*\bsize=([0-9]+)\b"
)
SYMBOL_RE = re.compile(r"^([0-9A-Fa-f]{6,})\s+([A-Za-z_.$?][\w.$?]*)$")
LABEL_RE = re.compile(r"^\s*([A-Za-z_.$?][\w.$?]*):")
EQU_RE = re.compile(r"^\s*([A-Za-z_.$?][\w.$?]*)\s+equ\s+(.+)$", re.IGNORECASE)
ASSIGN_RE = re.compile(r"^\s*%assign\s+([A-Za-z_.$?][\w.$?]*)\s+(.+)$")
DEFINE_RE = re.compile(r"^\s*%define\s+([A-Za-z_.$?][\w.$?]*)\s+(.+)$")
RES_RE = re.compile(r"^\s*(res[bdw])\s+(.+)$", re.IGNORECASE)
TIMES_RE = re.compile(r"^\s*times\s+(.+?)\s+(db|dw|dd)\b", re.IGNORECASE)
DUP_RE = re.compile(r"^\s*(db|dw|dd)\s+(.+?)\s+dup\s*\(", re.IGNORECASE)
GWRAM_R_RE = re.compile(r"^\s*R(?:INIT|1)?\s+([A-Za-z_.$?][\w.$?]*)\s*,\s*(.+)$")


OPS = {
    ast.Add: operator.add,
    ast.Sub: operator.sub,
    ast.Mult: operator.mul,
    ast.FloorDiv: operator.floordiv,
    ast.Div: operator.floordiv,
    ast.Mod: operator.mod,
    ast.LShift: operator.lshift,
    ast.RShift: operator.rshift,
    ast.BitOr: operator.or_,
    ast.BitAnd: operator.and_,
}
UNARY_OPS = {ast.UAdd: operator.pos, ast.USub: operator.neg, ast.Invert: operator.invert}
UNIT_SIZE = {"db": 1, "resb": 1, "dw": 2, "resw": 2, "dd": 4, "resd": 4}

DEFAULT_GROUPS = {
    "core-runtime": [
        "bimisc",
        "biptrg",
        "bistrs",
        "gweval",
        "gwinit",
        "gwmain",
        "gwram",
        "next86",
    ],
    "tables-data-tokens": ["gwdata", "ibmres"],
    "math-runtime-mixed": ["math1"],
    "program-list-edit": ["gwlist", "scnedt"],
    "screen-keyboard": ["dwio", "giocon", "giokyb", "gioscn", "giotbl", "scndrv"],
    "generic-io-core": ["gio86"],
    "fiveo-extensions": ["fiveo"],
    "print-using": ["biprtu"],
    "seg-init": ["itsa86"],
    "call-statement": ["call86"],
    "draw-macro-runtime": ["maclng"],
    "oem-stubs-and-hooks": ["dwstubs"],
}


@dataclass(frozen=True)
class ObjectSize:
    name: str
    path: str
    start: int
    size: int


@dataclass(frozen=True)
class MapInfo:
    path: Path
    load_offset: int
    objects: dict[str, ObjectSize]
    symbols: dict[str, int]

    @property
    def image_size(self) -> int:
        if not self.objects:
            return 0
        end = max(item.start + item.size for item in self.objects.values())
        return end - self.load_offset


@dataclass(frozen=True)
class Reservation:
    path: Path
    line: int
    label: str
    bytes: int
    expression: str


def strip_comment(line: str) -> str:
    return line.split(";", 1)[0].strip()


def clean_expr(expr: str) -> str:
    expr = expr.split(";", 1)[0].strip()
    expr = expr.replace("?", "0")
    expr = re.sub(r"\b([0-7]+)[oO]\b", r"0o\1", expr)
    return expr


def eval_expr(expr: str, names: dict[str, int]) -> int | None:
    expr = clean_expr(expr)
    if not expr:
        return None
    try:
        tree = ast.parse(expr, mode="eval")
    except SyntaxError:
        return None

    def visit(node: ast.AST) -> int:
        if isinstance(node, ast.Expression):
            return visit(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return int(node.value)
        if isinstance(node, ast.Name):
            if node.id not in names:
                raise KeyError(node.id)
            return names[node.id]
        if isinstance(node, ast.BinOp) and type(node.op) in OPS:
            return OPS[type(node.op)](visit(node.left), visit(node.right))
        if isinstance(node, ast.UnaryOp) and type(node.op) in UNARY_OPS:
            return UNARY_OPS[type(node.op)](visit(node.operand))
        raise ValueError(ast.dump(node))

    try:
        return visit(tree)
    except (KeyError, ValueError, ZeroDivisionError):
        return None


def parse_map(path: Path, load_offset: int) -> MapInfo:
    objects: dict[str, ObjectSize] = {}
    symbols: dict[str, int] = {}
    for line in path.read_text().splitlines():
        if match := OBJECT_RE.match(line):
            start = int(match.group(1), 16)
            obj_path = match.group(2)
            name = Path(obj_path).stem
            objects[name] = ObjectSize(name, obj_path, start, int(match.group(3)))
            continue
        if match := SYMBOL_RE.match(line):
            symbols[match.group(2)] = int(match.group(1), 16)
    return MapInfo(path, load_offset, objects, symbols)


def discover_source_files(root: Path, maps: list[MapInfo]) -> list[Path]:
    names = {name for info in maps for name in info.objects}
    files = [root / "src" / "gw" / f"{name}.asm" for name in sorted(names)]
    files += sorted((root / "src" / "include").glob("*.asm"))
    files += sorted((root / "src" / "include").glob("*.inc"))
    return [path for path in files if path.exists()]


def collect_constants(paths: list[Path]) -> dict[str, int]:
    names: dict[str, int] = {}
    for _ in range(4):
        changed = False
        for path in paths:
            for raw in path.read_text(errors="replace").splitlines():
                line = strip_comment(raw)
                match = EQU_RE.match(line) or ASSIGN_RE.match(line) or DEFINE_RE.match(line)
                if not match:
                    continue
                value = eval_expr(match.group(2), names)
                if value is None:
                    continue
                if names.get(match.group(1)) != value:
                    names[match.group(1)] = value
                    changed = True
        if not changed:
            break
    return names


def scan_reservations(paths: list[Path], names: dict[str, int], threshold: int) -> list[Reservation]:
    out: list[Reservation] = []
    for path in paths:
        last_label = ""
        for lineno, raw in enumerate(path.read_text(errors="replace").splitlines(), 1):
            if match := LABEL_RE.match(raw):
                last_label = match.group(1)
            line = strip_comment(raw)
            expr = None
            unit = None
            if match := RES_RE.match(line):
                unit = match.group(1).lower()
                expr = match.group(2)
            elif match := TIMES_RE.match(line):
                unit = match.group(2).lower()
                expr = match.group(1)
            elif match := DUP_RE.match(line):
                unit = match.group(1).lower()
                expr = match.group(2)
            elif match := GWRAM_R_RE.match(line):
                last_label = match.group(1)
                unit = "db"
                expr = match.group(2)
            if not expr or not unit:
                continue
            count = eval_expr(expr, names)
            if count is None:
                continue
            size = count * UNIT_SIZE[unit]
            if size >= threshold:
                out.append(Reservation(path, lineno, last_label or "(anonymous)", size, expr.strip()))
    return sorted(out, key=lambda item: (-item.bytes, str(item.path), item.line))


def print_object_table(info: MapInfo, limit: int) -> None:
    print("Object sizes:")
    for item in sorted(info.objects.values(), key=lambda obj: (-obj.size, obj.name))[:limit]:
        print(f"  {item.size:6d}  {item.name:<12} {item.path}")


def print_group_table(info: MapInfo, groups: dict[str, list[str]]) -> None:
    print("Profile groups:")
    print("  (object-level linked granularity; mixed objects may contain several features)")
    seen: set[str] = set()
    for group, names in groups.items():
        present = [info.objects[name] for name in names if name in info.objects]
        if not present:
            continue
        seen.update(item.name for item in present)
        size = sum(item.size for item in present)
        members = ", ".join(item.name for item in present)
        print(f"  {size:6d}  {group:<20} {members}")
    ungrouped = [item for name, item in info.objects.items() if name not in seen]
    if ungrouped:
        size = sum(item.size for item in ungrouped)
        members = ", ".join(sorted(item.name for item in ungrouped))
        print(f"  {size:6d}  {'ungrouped':<20} {members}")


def print_optional_delta(base: MapInfo, name: str, other: MapInfo) -> None:
    print()
    print(f"Optional profile: {name}")
    print(f"  image bytes: {other.image_size} ({other.image_size - base.image_size:+d})")
    rows: list[tuple[int, str, str]] = []
    for obj_name, obj in other.objects.items():
        old = base.objects.get(obj_name)
        delta = obj.size if old is None else obj.size - old.size
        if delta:
            kind = "new" if old is None else "delta"
            rows.append((delta, kind, obj_name))
    for delta, kind, obj_name in sorted(rows, key=lambda row: (-abs(row[0]), row[2])):
        print(f"  {delta:+6d}  {kind:<5} {obj_name}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--base-map", type=Path, default=Path("build/gw-basic.map"))
    parser.add_argument(
        "--optional-map",
        action="append",
        default=[],
        metavar="NAME=PATH",
        help="compare another map against the base map",
    )
    parser.add_argument("--load-offset", type=lambda text: int(text, 0), default=0x0800)
    parser.add_argument("--buffer-threshold", type=int, default=512)
    parser.add_argument("--top", type=int, default=12)
    parser.add_argument(
        "--group",
        action="append",
        default=[],
        metavar="NAME=OBJ,OBJ",
        help="add or replace a profile group",
    )
    args = parser.parse_args()

    root = args.root
    base_map_path = args.base_map if args.base_map.is_absolute() else root / args.base_map
    base = parse_map(base_map_path, args.load_offset)

    optional: list[tuple[str, MapInfo]] = []
    for spec in args.optional_map:
        if "=" not in spec:
            raise SystemExit(f"--optional-map must be NAME=PATH: {spec}")
        name, path_text = spec.split("=", 1)
        path = Path(path_text)
        if not path.is_absolute():
            path = root / path
        optional.append((name, parse_map(path, args.load_offset)))

    print(f"Base map: {base.path}")
    print(f"  image bytes: {base.image_size}")
    for symbol in ("INIT", "DW_LOADER_LIMIT", "LSTVAR"):
        if symbol in base.symbols:
            print(f"  {symbol}: 0x{base.symbols[symbol]:04X}")
    print()
    groups = {name: list(members) for name, members in DEFAULT_GROUPS.items()}
    for spec in args.group:
        if "=" not in spec:
            raise SystemExit(f"--group must be NAME=OBJ,OBJ: {spec}")
        name, members = spec.split("=", 1)
        groups[name] = [member.strip() for member in members.split(",") if member.strip()]

    print_group_table(base, groups)
    print()
    print_object_table(base, args.top)
    for name, info in optional:
        print_optional_delta(base, name, info)

    source_paths = discover_source_files(root, [base] + [info for _, info in optional])
    constants = collect_constants(source_paths)
    reservations = scan_reservations(source_paths, constants, args.buffer_threshold)

    print()
    print(f"Static reservations >= {args.buffer_threshold} bytes:")
    for item in reservations:
        rel = item.path.relative_to(root)
        print(f"  {item.bytes:6d}  {rel}:{item.line}  {item.label}  ({item.expression})")


if __name__ == "__main__":
    main()

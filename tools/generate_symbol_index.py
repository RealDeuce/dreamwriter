#!/usr/bin/env python3
"""Generate a sortable HTML symbol index from disassembly markdown labels."""

from __future__ import annotations

import argparse
import html
import re
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DOC_GLOBS = ["v2.1/docs/disassembly/*.md"]
DEFAULT_OUTPUT = Path("v2.1/docs/disassembly/symbol-index.html")

LABEL_RE = re.compile(r"^(?P<name>[A-Za-z_.$][A-Za-z0-9_.$-]*):\s*$")
ADDR_SUFFIX_RE = re.compile(r"_([0-9A-Fa-f]{4})_([0-9A-Fa-f]{4})$")
INSTRUCTION_RE = re.compile(r"^(?P<addr>[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4})\s+")


@dataclass(frozen=True)
class Symbol:
    address: str
    name: str
    source: Path
    line: int

    @property
    def sort_key(self) -> tuple[int, int, str, str, int]:
        seg, off = self.address.split(":")
        return (int(seg, 16), int(off, 16), self.name.lower(), str(self.source), self.line)

    @property
    def address_sort_value(self) -> int:
        seg, off = self.address.split(":")
        return (int(seg, 16) << 16) | int(off, 16)


def expand_docs(patterns: list[str]) -> list[Path]:
    paths: list[Path] = []
    for pattern in patterns:
        matched = sorted(Path().glob(pattern))
        paths.extend(path for path in matched if path.name != "symbol-index.html")
    return sorted(dict.fromkeys(paths))


def next_instruction_address(lines: list[str], start: int) -> str | None:
    for line in lines[start + 1 : min(start + 7, len(lines))]:
        match = INSTRUCTION_RE.match(line)
        if match:
            return match.group("addr").upper()
        if line.strip() and not line.startswith(";"):
            # A real intervening line means the label probably belongs to prose,
            # not the next disassembly snippet.
            break
    return None


def find_symbols(paths: list[Path]) -> list[Symbol]:
    symbols: list[Symbol] = []
    seen: set[tuple[str, str, str, int]] = set()
    for path in paths:
        if path.suffix != ".md":
            continue
        lines = path.read_text(encoding="utf-8").splitlines()
        for idx, line in enumerate(lines):
            match = LABEL_RE.match(line)
            if not match:
                continue
            name = match.group("name")
            suffix = ADDR_SUFFIX_RE.search(name)
            if suffix:
                address = f"{suffix.group(1).upper()}:{suffix.group(2).upper()}"
            else:
                address = next_instruction_address(lines, idx)
            if not address:
                continue
            key = (address, name, str(path), idx + 1)
            if key in seen:
                continue
            seen.add(key)
            symbols.append(Symbol(address=address, name=name, source=path, line=idx + 1))
    return sorted(symbols, key=lambda symbol: symbol.sort_key)


def render(symbols: list[Symbol]) -> str:
    rows = []
    for symbol in symbols:
        source_label = f"{symbol.source.name}:{symbol.line}"
        href = f"{html.escape(symbol.source.name)}#L{symbol.line}"
        rows.append(
            "      <tr>"
            f'<td data-sort="{symbol.address_sort_value}"><code>{html.escape(symbol.address)}</code></td>'
            f'<td data-sort="{html.escape(symbol.name.lower())}"><code>{html.escape(symbol.name)}</code></td>'
            f'<td data-sort="{html.escape(symbol.source.name.lower())}">'
            f'<a href="{href}">{html.escape(source_label)}</a></td>'
            "</tr>"
        )

    return """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DreamWriter T400 Disassembly Symbol Index</title>
  <style>
    :root {
      color-scheme: light dark;
      --border: #b8b8b8;
      --muted: #666;
      --row: rgba(127, 127, 127, 0.08);
      --accent: #245ea8;
    }
    body {
      font-family: system-ui, -apple-system, Segoe UI, sans-serif;
      line-height: 1.4;
      margin: 2rem;
      max-width: 72rem;
    }
    h1 {
      font-size: 1.6rem;
      margin-bottom: 0.25rem;
    }
    p {
      color: var(--muted);
      margin-top: 0;
    }
    input {
      box-sizing: border-box;
      font: inherit;
      margin: 1rem 0;
      max-width: 28rem;
      padding: 0.4rem 0.5rem;
      width: 100%;
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    th, td {
      border-bottom: 1px solid var(--border);
      padding: 0.35rem 0.5rem;
      text-align: left;
      vertical-align: top;
    }
    tbody tr:nth-child(even) {
      background: var(--row);
    }
    th button {
      all: unset;
      color: var(--accent);
      cursor: pointer;
      font-weight: 700;
    }
    th button::after {
      content: " \\2195";
      color: var(--muted);
      font-weight: 400;
    }
    th[aria-sort="ascending"] button::after {
      content: " \\2191";
    }
    th[aria-sort="descending"] button::after {
      content: " \\2193";
    }
    code {
      font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
      font-size: 0.92em;
    }
  </style>
</head>
<body>
  <h1>DreamWriter T400 Disassembly Symbol Index</h1>
  <p>Generated from named labels in <code>v2.1/docs/disassembly/*.md</code>. Click Address or Name to sort.</p>
  <input id="filter" type="search" placeholder="Filter symbols, addresses, or files" aria-label="Filter symbols">
  <table id="symbols">
    <thead>
      <tr>
        <th aria-sort="ascending"><button type="button" data-column="0">Address</button></th>
        <th><button type="button" data-column="1">Name</button></th>
        <th><button type="button" data-column="2">Source</button></th>
      </tr>
    </thead>
    <tbody>
""" + "\n".join(rows) + """
    </tbody>
  </table>
  <script>
    const table = document.getElementById("symbols");
    const tbody = table.tBodies[0];
    const headers = Array.from(table.tHead.rows[0].cells);
    const filter = document.getElementById("filter");

    function sortTable(column, reverse) {
      const rows = Array.from(tbody.rows);
      rows.sort((a, b) => {
        const av = a.cells[column].dataset.sort || a.cells[column].textContent;
        const bv = b.cells[column].dataset.sort || b.cells[column].textContent;
        const an = Number(av);
        const bn = Number(bv);
        const cmp = Number.isFinite(an) && Number.isFinite(bn)
          ? an - bn
          : av.localeCompare(bv, undefined, { numeric: true });
        return reverse ? -cmp : cmp;
      });
      rows.forEach(row => tbody.appendChild(row));
      headers.forEach(header => header.removeAttribute("aria-sort"));
      headers[column].setAttribute("aria-sort", reverse ? "descending" : "ascending");
    }

    headers.forEach((header, index) => {
      header.querySelector("button").addEventListener("click", () => {
        const reverse = header.getAttribute("aria-sort") === "ascending";
        sortTable(index, reverse);
      });
    });

    filter.addEventListener("input", () => {
      const needle = filter.value.trim().toLowerCase();
      Array.from(tbody.rows).forEach(row => {
        row.hidden = needle && !row.textContent.toLowerCase().includes(needle);
      });
    });
  </script>
</body>
</html>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--docs", action="append", help="Markdown glob to scan. Repeatable.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true", help="Fail if output is stale.")
    args = parser.parse_args()

    docs = expand_docs(args.docs or DEFAULT_DOC_GLOBS)
    content = render(find_symbols(docs))
    if args.check:
        try:
            old = args.output.read_text(encoding="utf-8")
        except FileNotFoundError:
            print(f"{args.output}: missing; regenerate with tools/generate_symbol_index.py", file=sys.stderr)
            return 1
        if old != content:
            print(f"{args.output}: stale; regenerate with tools/generate_symbol_index.py", file=sys.stderr)
            return 1
        return 0

    args.output.write_text(content, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

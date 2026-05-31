#!/usr/bin/env python3
"""Decode DreamWriter LCD snapshots using the ROM 6x8 text font.

This is intentionally strict.  A cell is decoded only if its pixels exactly
match one ROM glyph rendered as the firmware text path displays it: eight rows
high, with the left six columns of the 8x8 glyph slot.  Any non-text pixels
cause a diagnostic error instead of a best-effort OCR guess.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


MAIN_GLYPH_BASE = 0x580B6
BOLD_GLYPH_BASE = 0x586B6
SMALL_GLYPH_BASE = 0x58CB6
SMALL_BOLD_GLYPH_BASE = 0x592B6
FIRST_CODE = 0x20
DEFAULT_LAST_CODE = 0x7E
CELL_W = 6
CELL_H = 8
ATTR_UNDERLINE = 0x1
ATTR_INVERSE = 0x2
ATTR_BOLD = 0x4
ATTR_SMALL = 0x8
ATTR_SUPERSCRIPT = 0x10


@dataclass(frozen=True)
class DecodedCell:
    char: str
    attrs: int


def parse_int(text: str) -> int:
    return int(text, 0)


def glyph_cell(rom: bytes, base: int, code: int, first_code: int) -> tuple[int, ...]:
    index = code - first_code
    if index < 0:
        raise ValueError(f"code 0x{code:02x} is before first code 0x{first_code:02x}")
    offset = base + index * CELL_H
    end = offset + CELL_H
    if offset < 0 or end > len(rom):
        raise ValueError(f"glyph 0x{code:02x} at 0x{offset:x} is outside ROM")
    rows: list[int] = []
    for byte in rom[offset:end]:
        row = 0
        for bit in range(CELL_W):
            if byte & (0x80 >> bit):
                row |= 1 << (CELL_W - 1 - bit)
        rows.append(row)
    return tuple(rows)


def build_templates(
    rom: bytes,
    base: int,
    first_code: int,
    last_code: int,
) -> dict[tuple[int, ...], DecodedCell]:
    templates: dict[tuple[int, ...], DecodedCell] = {}
    ambiguous: dict[tuple[int, ...], list[int]] = {}
    for code in range(first_code, last_code + 1):
        cell = glyph_cell(rom, base, code, first_code)
        ambiguous.setdefault(cell, []).append(code)

    for cell, codes in ambiguous.items():
        printable_codes = [code for code in codes if 0x20 <= code <= 0x7E]
        chosen = printable_codes[0] if printable_codes else codes[0]
        char = chr(chosen) if 0x20 <= chosen <= 0x7E else f"\\x{chosen:02X}"
        templates[cell] = DecodedCell(char, 0)
    return templates


def underline_cell(cell: tuple[int, ...]) -> tuple[int, ...]:
    return (*cell[:-1], (1 << CELL_W) - 1)


def invert_cell(cell: tuple[int, ...]) -> tuple[int, ...]:
    mask = (1 << CELL_W) - 1
    return tuple((~row) & mask for row in cell)


def superscript_cell(cell: tuple[int, ...]) -> tuple[int, ...]:
    leading = 0
    for row in cell:
        if row:
            break
        leading += 1
    if leading == 0 or leading == len(cell):
        return cell
    return (*cell[leading:], *(0 for _ in range(leading)))


def build_attribute_templates(
    rom: bytes,
    first_code: int,
    last_code: int,
) -> dict[tuple[int, ...], DecodedCell]:
    templates: dict[tuple[int, ...], DecodedCell] = {}
    font_runs = [
        (MAIN_GLYPH_BASE, 0),
        (BOLD_GLYPH_BASE, ATTR_BOLD),
        (SMALL_GLYPH_BASE, ATTR_SMALL),
        (SMALL_BOLD_GLYPH_BASE, ATTR_SMALL | ATTR_BOLD),
    ]
    for base, font_attrs in font_runs:
        rendered_attrs = font_attrs
        if font_attrs & ATTR_SMALL:
            rendered_attrs |= ATTR_SUPERSCRIPT
        for code in range(first_code, last_code + 1):
            char = chr(code) if 0x20 <= code <= 0x7E else f"\\x{code:02X}"
            cell = glyph_cell(rom, base, code, first_code)
            if font_attrs & ATTR_SMALL:
                cell = superscript_cell(cell)
            if char == " ":
                # Blank spaces look identical in every font page, so bold/small
                # are not visible attributes until another glyph is drawn.
                templates.setdefault(cell, DecodedCell(char, 0))
            else:
                templates[cell] = DecodedCell(char, rendered_attrs)
            templates.setdefault(invert_cell(cell), DecodedCell(char, rendered_attrs | ATTR_INVERSE))
            underlined = underline_cell(cell)
            templates.setdefault(underlined, DecodedCell(char, rendered_attrs | ATTR_UNDERLINE))
            templates.setdefault(invert_cell(underlined), DecodedCell(char, rendered_attrs | ATTR_UNDERLINE | ATTR_INVERSE))
        if first_code <= 0x20 <= last_code:
            space_cell = glyph_cell(rom, base, 0x20, first_code)
            if font_attrs & ATTR_SMALL:
                space_cell = superscript_cell(space_cell)
            underlined_space = underline_cell(space_cell)
            templates[underlined_space] = DecodedCell(" ", ATTR_UNDERLINE)
            templates[invert_cell(underlined_space)] = DecodedCell(" ", ATTR_UNDERLINE | ATTR_INVERSE)
    return templates


def threshold_pixels(image: Image.Image) -> list[list[bool]]:
    rgb = image.convert("RGB")
    colors = rgb.getcolors(maxcolors=1 << 24)
    if not colors:
        raise ValueError("unable to enumerate image colors")
    colors = sorted(colors, reverse=True)
    if len(colors) < 2:
        raise ValueError("snapshot has fewer than two colors")

    by_luma = sorted((sum(color), color) for _, color in colors)
    fg_luma, _ = by_luma[0]
    bg_luma, _ = by_luma[-1]
    if fg_luma == bg_luma:
        raise ValueError("snapshot foreground/background threshold is degenerate")
    threshold = (fg_luma + bg_luma) / 2

    width, height = rgb.size
    return [
        [sum(rgb.getpixel((x, y))) < threshold for x in range(width)]
        for y in range(height)
    ]


def extract_cell(bits: list[list[bool]], col: int, row: int) -> tuple[int, ...]:
    x0 = col * CELL_W
    y0 = row * CELL_H
    rows: list[int] = []
    for y in range(y0, y0 + CELL_H):
        value = 0
        for x in range(x0, x0 + CELL_W):
            if bits[y][x]:
                value |= 1 << (CELL_W - 1 - (x - x0))
        rows.append(value)
    return tuple(rows)


def render_cell(cell: tuple[int, ...]) -> str:
    lines = []
    for row in cell:
        lines.append("".join("#" if row & (1 << (CELL_W - 1 - bit)) else "." for bit in range(CELL_W)))
    return "\n".join(lines)


def decode_image(
    image: Image.Image,
    templates: dict[tuple[int, ...], DecodedCell],
    trim: bool,
    allow_cursor: bool,
    allow_inverse: bool,
    cursor_char: str,
) -> list[list[DecodedCell]]:
    width, height = image.size
    if width % CELL_W or height % CELL_H:
        raise ValueError(f"snapshot size {width}x{height} is not divisible by {CELL_W}x{CELL_H}")

    bits = threshold_pixels(image)
    cols = width // CELL_W
    rows = height // CELL_H
    decoded: list[list[DecodedCell]] = []
    for row in range(rows):
        cells: list[DecodedCell] = []
        for col in range(cols):
            cell = extract_cell(bits, col, row)
            decoded_cell = templates.get(cell)
            if decoded_cell is None and allow_inverse:
                inverted = templates.get(invert_cell(cell))
                if inverted is not None:
                    decoded_cell = DecodedCell(inverted.char, inverted.attrs | ATTR_INVERSE)
            if decoded_cell is None and allow_cursor and all(value == (1 << CELL_W) - 1 for value in cell):
                decoded_cell = DecodedCell(cursor_char, ATTR_INVERSE)
            if decoded_cell is None:
                raise ValueError(
                    f"non-text cell at row={row} col={col} x={col * CELL_W} y={row * CELL_H}\n"
                    f"{render_cell(cell)}"
                )
            cells.append(decoded_cell)
        if trim:
            while cells and cells[-1].char == " ":
                cells.pop()
        decoded.append(cells)
    return decoded


def cells_to_text(cells: list[DecodedCell]) -> str:
    return "".join(cell.char for cell in cells)


def cells_to_attrs(cells: list[DecodedCell]) -> str:
    return "".join(f"{cell.attrs:02X}" if cell.attrs else ".." for cell in cells)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("png", type=Path, help="MAME drwrt400 LCD snapshot PNG")
    parser.add_argument("--rom", type=Path, default=Path("t4_ir_2.1.ic303"), help="DreamWriter ROM image")
    parser.add_argument("--font-base", type=parse_int, default=MAIN_GLYPH_BASE)
    parser.add_argument("--first-code", type=parse_int, default=FIRST_CODE)
    parser.add_argument("--last-code", type=parse_int, default=DEFAULT_LAST_CODE)
    parser.add_argument("--no-trim", action="store_true", help="preserve trailing spaces")
    parser.add_argument(
        "--allow-cursor",
        action="store_true",
        help="decode an all-lit text cell as the active inverse cursor instead of failing",
    )
    parser.add_argument(
        "--allow-inverse",
        action="store_true",
        help="decode exact bitwise-inverted ROM glyphs as text",
    )
    parser.add_argument(
        "--attrs",
        action="store_true",
        help="print one attribute-mask line after each decoded text line",
    )
    parser.add_argument("--cursor-char", default=" ", help="character to emit for --allow-cursor")
    args = parser.parse_args(argv)

    try:
        rom = args.rom.read_bytes()
        image = Image.open(args.png)
        if args.attrs:
            templates = build_attribute_templates(rom, args.first_code, args.last_code)
        else:
            templates = build_templates(rom, args.font_base, args.first_code, args.last_code)
            templates.update(build_attribute_templates(rom, args.first_code, args.last_code))
        for cells in decode_image(
            image,
            templates,
            trim=not args.no_trim,
            allow_cursor=args.allow_cursor,
            allow_inverse=args.allow_inverse,
            cursor_char=args.cursor_char,
        ):
            print(cells_to_text(cells))
            if args.attrs:
                print(cells_to_attrs(cells))
    except (OSError, ValueError) as exc:
        print(f"{args.png}: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

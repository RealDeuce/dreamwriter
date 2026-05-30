#!/usr/bin/env python3
"""Small MASM-to-NASM mechanical converter for the DreamWriter GW-BASIC port.

This is deliberately conservative. It handles the common translated-ASM86
surface and leaves hard cases visible as NASM compile errors instead of trying
to be clever.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


COMMENT_BLOCK_RE = re.compile(r"^\s*COMMENT\s+(.).*")
CURRENT_RADIX = 10
REGISTERS = {
    "al",
    "ah",
    "ax",
    "bl",
    "bh",
    "bx",
    "cl",
    "ch",
    "cx",
    "dl",
    "dh",
    "dx",
    "si",
    "di",
    "bp",
    "sp",
    "cs",
    "ds",
    "es",
    "ss",
}
SYMBOL_RENAMES = {
    "COMMON": "BASIC_COMMON",
    "FLOAT": "FLOAT_SUB",
    "TIMES": "TIMES_STMT",
    "VIEW": "VIEW_STMT",
    "WINDOW": "WINDOW_STMT",
}
TOKEN_CONSTANT_NAMES = {
    "ABS",
    "ASC",
    "ATN",
    "AUTO",
    "BEEP",
    "BLOAD",
    "BSAVE",
    "CALL",
    "CALLS",
    "CDBL",
    "CHAIN",
    "CHR",
    "CINT",
    "CLEAR",
    "CLOSE",
    "CLS",
    "COLOR",
    "COM",
    "COMMON",
    "CONT",
    "COS",
    "CSNG",
    "CVI",
    "CVD",
    "CVS",
    "DATA",
    "DATE",
    "DEF",
    "DEFDBL",
    "DEFINT",
    "DEFSNG",
    "DEFSTR",
    "DELETE",
    "DIM",
    "EDIT",
    "ELSE",
    "END",
    "EOF",
    "ERL",
    "ERR",
    "ERROR",
    "EXP",
    "FIELD",
    "FILES",
    "FN",
    "FOR",
    "FRE",
    "GET",
    "GOSUB",
    "GOTO",
    "HEX",
    "IF",
    "INKEY$",
    "INP",
    "INPUT",
    "INSTR",
    "INT",
    "IOCTL",
    "KEY",
    "KEY2B",
    "KILL",
    "LEFT$",
    "LEN",
    "LET",
    "LINE",
    "LIST",
    "LLIST",
    "LOAD",
    "LOC",
    "LOCATE",
    "LOF",
    "LOG",
    "LPOS",
    "LPRINT",
    "LSET",
    "MERGE",
    "MID$",
    "MKD",
    "MKI",
    "MKS",
    "MOD",
    "MOTOR",
    "NAME",
    "NEW",
    "NEXT",
    "NOT",
    "OCT",
    "OFF",
    "ON",
    "OPEN",
    "OPTION",
    "OUT",
    "PEEK",
    "PEN",
    "POINT",
    "POKE",
    "POS",
    "PRESET",
    "PRINT",
    "PSET",
    "PUT",
    "RANDOMIZE",
    "READ",
    "REM",
    "RENUM",
    "RESET",
    "RESTORE",
    "RESUME",
    "RETURN",
    "RIGHT$",
    "RND",
    "RSET",
    "RUN",
    "SAVE",
    "SCREEN",
    "SGN",
    "SIN",
    "SOUND",
    "SPACE$",
    "SPC",
    "SQR",
    "STEP",
    "STICK",
    "STOP",
    "STR$",
    "STRING$",
    "STRIG",
    "SWAP",
    "SYSTEM",
    "TAB",
    "TAN",
    "THEN",
    "TIME",
    "TO",
    "TROFF",
    "TRON",
    "USR",
    "USING",
    "VAL",
    "VARPTR",
    "WAIT",
    "WEND",
    "WHILE",
    "WIDTH",
    "WRITE",
}
TOKEN_ALIAS_NAMES = {
    "ATNTK",
    "CLINTK",
    "DIVTK",
    "EQULTK",
    "ERCTK",
    "ERLTK",
    "EXPTK",
    "FNTK",
    "GREATK",
    "IDIVTK",
    "INSRTK",
    "LESSTK",
    "LSTOPK",
    "MIDTK",
    "MINUTK",
    "MULTK",
    "NOTTK",
    "PLUSTK",
    "SNGQTK",
    "SPCTK",
    "SQRTK",
    "STEPTK",
    "TABTK",
    "THENTK",
    "USINTK",
    "USRTK",
}
ERROR_CONSTANT_NAMES = {
    "DSKERR",
    "DSKER1",
    "ERROM",
    "ERRADV",
    "ERRBFM",
    "ERRBFN",
    "ERRBRN",
    "ERRBS",
    "ERRCBO",
    "ERRCN",
    "ERRDD",
    "ERRDFL",
    "ERRDIO",
    "ERRDME",
    "ERRDNA",
    "ERRDNR",
    "ERRDPE",
    "ERRDTO",
    "ERRDV0",
    "ERRDVF",
    "ERRDWP",
    "ERRFC",
    "ERRFDR",
    "ERRFNF",
    "ERRFNO",
    "ERRFN",
    "ERRFOV",
    "ERRIER",
    "ERRID",
    "ERRIFN",
    "ERRIOE",
    "ERRLBO",
    "ERRLS",
    "ERRMMM",
    "ERRMO",
    "ERRNF",
    "ERRNMF",
    "ERRNR",
    "ERROD",
    "ERROM",
    "ERROTP",
    "ERROV",
    "ERRRAD",
    "ERRRE",
    "ERRRG",
    "ERRRPE",
    "ERRSN",
    "ERRSO",
    "ERRST",
    "ERRTM",
    "ERRTMF",
    "ERRUE",
    "ERRUE1",
    "ERRUF",
    "ERRUS",
    "ERRWE",
    "ERRWH",
    "LSTERR",
    "NONDSK",
}
DEVICE_CONSTANT_NAMES = {
    "DOL__CONS",
    "DOL__KYBD",
    "DOL__LPT1",
    "DOL__NDEV",
    "DOL__SCRN",
}
ABSOLUTE_CONSTANT_NAMES = {
    "BOTCON",
    "CONCN2",
    "CONCON",
    "DBLCON",
    "DBLCN1",
    "DOL_DATCO",
    "DOL_COM2B",
    "DOL_KEY2B",
    "DOL_PEN2B",
    "DOL_REMCO",
    "DOL_RNDFN",
    "DOL_STR2B",
    "HEXCON",
    "IN2CON",
    "INTCON",
    "LINCON",
    "NMREL",
    "NUMCMD",
    "NUMGFN",
    "OCTCON",
    "ONECON",
    "ONEFUN",
    "PTRCON",
    "PRMSIZ",
    "SNGCON",
    "T_ON",
    "T_REQ",
    "T_STOP",
    "TOPCON",
}


def split_comment(line: str) -> tuple[str, str]:
    in_string = False
    for i, ch in enumerate(line):
        if ch == '"':
            in_string = not in_string
        elif ch == ";" and not in_string:
            return line[:i], line[i:]
    return line, ""


def split_quoted(text: str) -> list[tuple[bool, str]]:
    parts: list[tuple[bool, str]] = []
    start = 0
    in_string = False
    i = 0
    while i < len(text):
        if text[i] == '"':
            if in_string:
                parts.append((True, text[start : i + 1]))
                start = i + 1
                in_string = False
            else:
                if start != i:
                    parts.append((False, text[start:i]))
                start = i
                in_string = True
        i += 1
    if start < len(text):
        parts.append((in_string, text[start:]))
    return parts


def convert_numbers_for_radix(text: str) -> str:
    protected: list[str] = []

    def protect_decimal(match: re.Match[str]) -> str:
        protected.append(match.group(1))
        return f"__DWDEC{len(protected) - 1}__"

    def convert_part(part: str) -> str:
        part = re.sub(r"\b([0-9]+)D\b", protect_decimal, part)
        part = re.sub(r"\b([0-7]+)O\b", lambda m: "0o" + m.group(1), part)
        if CURRENT_RADIX == 8:
            part = re.sub(r"(?<![A-Za-z0-9_])([0-7]+)(?![A-Za-z0-9_])", lambda m: "0o" + m.group(1), part)
        for i, value in enumerate(protected):
            part = part.replace(f"__DWDEC{i}__", value)
        return part

    return "".join(chunk if quoted else convert_part(chunk) for quoted, chunk in split_quoted(text))


def convert_expr(text: str) -> str:
    text = re.sub(
        r"\b(?:LOW\s+)?OFFSET\s+([A-Za-z_?][\w.$?]*)",
        lambda m: "ERRC_" + m.group(1) if m.group(1).upper() in ERROR_CONSTANT_NAMES else m.group(0),
        text,
        flags=re.I,
    )
    text = re.sub(
        r"\b(?:LOW\s+)?OFFSET\s+\$([A-Za-z_?][\w.$?]*)",
        lambda m: "TOK_" + m.group(1).replace("$", "") if m.group(1).upper() in TOKEN_CONSTANT_NAMES else "DOL_" + m.group(1),
        text,
        flags=re.I,
    )
    text = re.sub(r"\$([A-Za-z_?][\w.$?]*)", r"DOL_\1", text)
    for old, new in SYMBOL_RENAMES.items():
        text = re.sub(rf"\b{re.escape(old)}\b", new, text)
    text = text.replace("OFFSET ", "")
    text = re.sub(r"\bLOW\s+", "", text)
    text = re.sub(r"\bHIGH\s+", "", text)
    text = convert_numbers_for_radix(text)
    text = re.sub(r'("[^"]+"|[A-Za-z_.$?][\w.$?]*|[0-9]+|0o[0-7]+)\s+AND\s+("[^"]+"|[A-Za-z_.$?][\w.$?]*|[0-9]+|0o[0-7]+)', r"\1 & \2", text)
    return text


def convert_if_expr(text: str) -> str:
    text = convert_expr(text)
    text = re.sub(r"\bOR\b", "|", text, flags=re.I)
    text = re.sub(r"\bAND\b", "&", text, flags=re.I)
    return text


def rename_symbol(name: str) -> str:
    name = re.sub(r"^\$([A-Za-z_?][\w.$?]*)", r"DOL_\1", name)
    return SYMBOL_RENAMES.get(name.upper(), name)


def is_absolute_name(name: str) -> bool:
    is_dollar_token = name.startswith("$")
    raw = name[1:].upper() if is_dollar_token else name.upper()
    renamed = rename_symbol(name).upper()
    return (
        (is_dollar_token and raw in TOKEN_CONSTANT_NAMES)
        or renamed.startswith("TOK_")
        or renamed in TOKEN_ALIAS_NAMES
        or renamed in ERROR_CONSTANT_NAMES
        or renamed in DEVICE_CONSTANT_NAMES
        or renamed in ABSOLUTE_CONSTANT_NAMES
    )


def convert_db_dw_operands(text: str) -> str:
    text = convert_expr(text)
    text = re.sub(r"\bDUP\s*\(\s*\?\s*\)", "dup (?)", text, flags=re.I)
    text = re.sub(r"\bDUP\s*\(", "dup (", text, flags=re.I)
    text = re.sub(
        r"\b([A-Za-z_.$?][\w.$?]*(?:[+\-*/][A-Za-z0-9_.$?]+)*)\s+dup\s*\(",
        r"(\1) dup (",
        text,
        flags=re.I,
    )
    return text


def split_label(stripped: str) -> tuple[str, str]:
    m = re.match(r"([A-Za-z_.$?][\w.$?]*:)\s*(.*)$", stripped)
    if not m:
        return "", stripped
    return rename_symbol(m.group(1)[:-1]) + ":\t", m.group(2)


def convert_octal_byte(text: str) -> str:
    text = text.strip()
    if re.fullmatch(r"[0-7]+", text):
        return "0o" + text
    return convert_expr(text)


def wrap_memory_destination(match: re.Match[str]) -> str:
    op = match.group(1)
    operand = match.group(2)
    if operand.lower() in REGISTERS:
        return match.group(0)
    return f"{op}\t[{operand}]"


def convert_instruction(code: str) -> str:
    stripped = code.strip()
    if not stripped:
        return code

    # Segment boilerplate.
    upper = stripped.upper()
    if upper.endswith("SEGMENT PUBLIC 'CODESG'") or upper.endswith("SEGMENT PUBLIC 'DATASG'"):
        return ""
    if upper.endswith("ENDS"):
        return ""
    if upper.startswith("ASSUME"):
        return ""
    if upper in {".SALL", ".XLIST", ".LIST", "PAGE", "END"}:
        return ""
    if upper.startswith("SUBTTL") or upper.startswith("TITLE"):
        return "; " + stripped
    if upper.startswith(".RADIX"):
        return "; " + stripped

    if upper == "ENDIF":
        return "%endif"
    if upper == "ELSE":
        return "%else"

    m = re.match(r"IF\s+(.+)$", stripped, flags=re.I)
    if m:
        return "%if " + convert_if_expr(m.group(1))
    m = re.match(r"IFE\s+(.+)$", stripped, flags=re.I)
    if m:
        return "%if !(" + convert_if_expr(m.group(1)) + ")"
    m = re.match(r"IFN\s+(.+)$", stripped, flags=re.I)
    if m:
        return "%if " + convert_if_expr(m.group(1))

    m = re.match(r"INCLUDE\s+(.+)$", stripped, flags=re.I)
    if m:
        name = m.group(1).strip().strip('"').lower()
        if name == "oem.h":
            return '%include "dwoem.inc"'
        if name == "bintrp.h":
            return '%include "dwoem.inc"'
        if name == "gio86u":
            return '%include "gio86u.inc"'
        if name == "msdosu":
            return '%include "msdosu.inc"'
        return "; TODO include " + m.group(1).strip()

    if re.match(r"[A-Za-z_.$?][\w.$?]*\s+MACRO\b", stripped, flags=re.I):
        return ""
    if upper == "ENDM":
        return ""

    m = re.match(r"PUBLIC\s+(.+)$", stripped, flags=re.I)
    if m:
        names = [rename_symbol(n.strip()) for n in m.group(1).split(",") if not is_absolute_name(n.strip())]
        return "\n".join("global " + n for n in names if n)

    m = re.match(r"EXTRN\s+(.+)$", stripped, flags=re.I)
    if m:
        out: list[str] = []
        for item in m.group(1).split(","):
            raw_name = item.strip().split(":")[0].strip()
            name = rename_symbol(raw_name)
            if is_absolute_name(raw_name):
                continue
            if name:
                out.append("extern " + name)
        return "\n".join(out)

    m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s+LABEL\s+(BYTE|WORD|DWORD)\b", stripped, flags=re.I)
    if m:
        return rename_symbol(m.group(1)) + ":"

    m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s*=\s*(.+)$", stripped)
    if m:
        name = rename_symbol(m.group(1))
        expr = convert_expr(m.group(2).strip())
        if name in {"DATAS", "FORSZC"}:
            return name + " equ " + expr
        if re.search(rf"\b{re.escape(name)}\b", expr):
            return "%assign " + name + " " + expr
        if re.fullmatch(r"[0-9]+", expr):
            return "%assign " + name + " " + expr
        return "%define " + name + " " + expr

    m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s+EQU\s+(.+)$", stripped, flags=re.I)
    if m:
        return rename_symbol(m.group(1)) + " equ " + convert_expr(m.group(2).strip())

    m = re.match(r"ORG\s+(.+)$", stripped, flags=re.I)
    if m:
        return "; org " + convert_expr(m.group(1).strip())

    m = re.match(r"([A-Za-z_.$?][\w.$?]*:)?\s*(DB|DW|DD)\s+(.+)$", stripped, flags=re.I)
    if m:
        label = (rename_symbol(m.group(1)[:-1]) + ":" if m.group(1) else "")
        directive = m.group(2).lower()
        operands = convert_db_dw_operands(m.group(3))
        return (label + " " if label else "") + directive + " " + operands

    label, body = split_label(stripped)
    m = re.match(r"INS86\s+(.+)$", body, flags=re.I)
    if m:
        args = [arg.strip() for arg in m.group(1).split(",")]
        while args and args[-1] == "":
            args.pop()
        if len(args) == 1:
            return label + "db " + convert_octal_byte(args[0])
        if len(args) == 2:
            return label + "db " + ", ".join(convert_octal_byte(arg) for arg in args)
        if len(args) == 3:
            return "\n".join(
                [
                    label + "db " + convert_octal_byte(args[0]),
                    "dw " + convert_expr(args[2]),
                ]
            )
        if len(args) == 4:
            return "\n".join(
                [
                    label + "db " + convert_octal_byte(args[0]),
                    "db " + convert_octal_byte(args[1]),
                    "db " + convert_octal_byte(args[2]),
                    "db " + convert_octal_byte(args[3]),
                ]
            )

    m = re.match(r"MOVRI\s+(.+)$", body, flags=re.I)
    if m:
        args = [arg.strip() for arg in m.group(1).split(",")]
        if len(args) == 4:
            return "\n".join(
                [
                    label + "db 0o271",
                    "db " + convert_octal_byte(args[1]),
                    "db " + convert_octal_byte(args[0]),
                    "db 0o272",
                    "db " + convert_octal_byte(args[3]),
                    "db " + convert_octal_byte(args[2]),
                ]
            )

    m = re.match(r"DERMAK\s+([A-Za-z0-9_.$?]+)$", body, flags=re.I)
    if m:
        suffix = m.group(1).upper()
        return "\n".join(
            [
                f"global DER{suffix}",
                f"DER{suffix}:",
                f"mov dl, ERRC_ERR{suffix}",
                "jmp ERROR",
            ]
        )

    m = re.match(r"ADR\s+(.+)$", body, flags=re.I)
    if m:
        return label + "dw " + convert_expr(m.group(1))

    m = re.match(r"ADRP\s+(.+)$", body, flags=re.I)
    if m:
        return ""

    m = re.match(r"DOSIO\s+(.+)$", body, flags=re.I)
    if m:
        return "\n".join(
            [
                label + "mov ah, " + convert_expr(m.group(1)),
                "int 33",
            ]
        )
    m = re.match(r"CALLOS(?:\s+(.+))?$", body, flags=re.I)
    if m:
        if m.group(1):
            return "\n".join(
                [
                    label + "mov ah, " + convert_expr(m.group(1)),
                    "int 33",
                ]
            )
        return label + "int 33"
    if re.match(r"POPR$", body, flags=re.I):
        return "\n".join([label + "pop cx", "pop dx"])
    if re.match(r"ACRLF$", body, flags=re.I):
        return label + "db 13, 10"
    if re.match(r"DO_EXT$", body, flags=re.I):
        return "; DO_EXT handled by explicit extern declarations"

    # Common instruction expression fixes.
    code = convert_expr(code)
    code = re.sub(r"\bMOV\s+CH,\s*CNSLEN\+3\b", "mov cx, CNSLEN+3\nmov ch, cl", code, flags=re.I)
    code = re.sub(r"\bXLAT\s+BYTE PTR\s+\?CSLAB\b", "xlatb", code, flags=re.I)
    code = re.sub(r"\bMOVS\s+\?CSLAB,\s*WORD PTR\s+\?CSLAB\b", "cs movsw", code, flags=re.I)
    code = re.sub(r"\bLODS\s+WORD PTR\s+\?CSLAB\b", "cs lodsw", code, flags=re.I)
    code = re.sub(r"\bLODS\s+BYTE PTR\s+\?CSLAB\b", "cs lodsb", code, flags=re.I)
    code = re.sub(r"\bSHORT\s+", "", code, flags=re.I)
    code = re.sub(r"\bBYTE PTR\b", "byte", code, flags=re.I)
    code = re.sub(r"\bWORD PTR\b", "word", code, flags=re.I)
    code = re.sub(r"\bDWORD PTR\b", "dword", code, flags=re.I)
    code = re.sub(r"(?<![\w])-0o([0-7]+)\[([^\]]+)\]", r"[\2-0o\1]", code)
    code = re.sub(r"\b0o([0-7]+)\[([^\]]+)\]", r"[\2+0o\1]", code)
    code = re.sub(r"\b([0-9]+)\[([^\]]+)\]", r"[\2+\1]", code)
    code = re.sub(r"\b(word|byte|dword)\s+-\[([A-Za-z]{2})\+([0-9]+)\]", r"\1 [\2-\3]", code, flags=re.I)
    code = re.sub(r"\b([A-Za-z_.$?][\w.$?]*)-\[([^\]]+)\+0o([0-7]+)\]", r"[\1+\2-0o\3]", code)
    code = re.sub(r"\b([A-Za-z_.$?][\w.$?]*)-\[([A-Za-z]{2})\+([0-9]+)\]", r"[\1+\2-\3]", code)
    code = re.sub(r"\b(CS|DS|ES|SS):-\[([^\]]+)\+([0-9]+)\]", r"\1:[\2-\3]", code, flags=re.I)
    code = re.sub(r"\b([A-Za-z_.$?][\w.$?]*)\[([A-Za-z]{2})\]", r"[\1+\2]", code)
    code = re.sub(r"\[([A-Za-z]{2})\]:\[([^\]]+)\]", r"[\1:\2]", code)
    code = re.sub(r"\b(word|byte|dword)\s+\[([A-Za-z]{2})\]:\[([^\]]+)\]", r"\1 [\2:\3]", code, flags=re.I)
    code = re.sub(r"\b(word|byte|dword)\s+(CS|DS|ES|SS):\[([^\]]+)\]", r"\1 [\2:\3]", code, flags=re.I)
    code = re.sub(r"\bLES\s+([A-Za-z]{2}),\s*dword\s+\[([^\]]+)\]", r"LES \1, [\2]", code, flags=re.I)
    code = re.sub(
        r"\b(byte|word|dword)\s+([A-Za-z_.$?][\w.$?]*(?:[+-](?:[0-9]+|0o[0-7]+))?)\b",
        r"\1 [\2]",
        code,
        flags=re.I,
    )
    code = re.sub(r"\b([A-Za-z_.$?][\w.$?]*(?:[+\-*/][A-Za-z0-9_.$?]+)+)\s+dup\s*\(", r"(\1) dup (", code, flags=re.I)
    code = re.sub(r"\bLES\s+([A-Za-z]{2}),\s*dword\s+\[([^\]]+)\]", r"LES \1, [\2]", code, flags=re.I)
    code = re.sub(
        r"\b(MOV|ADD|ADC|SUB|SBB|CMP|XCHG|INC|DEC|NEG|NOT|OR|AND|XOR|TEST)\s+"
        r"([A-Za-z_.$?][\w.$?]*(?:[+-](?:[0-9]+|0o[0-7]+))?)(?=\s*(?:,|$))",
        wrap_memory_destination,
        code,
        flags=re.I,
    )
    return code


def convert_file(src: Path, dst: Path) -> None:
    global CURRENT_RADIX
    dst.parent.mkdir(parents=True, exist_ok=True)
    out: list[str] = [
        "; Auto-converted mechanically from " + str(src),
        "; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.",
        "",
    ]
    in_comment_block: str | None = None
    in_macro_block = False
    CURRENT_RADIX = 10
    for line in src.read_text(errors="replace").splitlines():
        if in_comment_block is not None:
            if line.strip() == in_comment_block:
                in_comment_block = None
            else:
                out.append("; " + line)
            continue
        if in_macro_block:
            if line.strip().upper() == "ENDM":
                in_macro_block = False
            continue

        m = COMMENT_BLOCK_RE.match(line)
        if m:
            in_comment_block = m.group(1)
            out.append("; COMMENT " + in_comment_block)
            continue

        code, comment = split_comment(line)
        radix_match = re.match(r"\s*\.RADIX\s+([0-9]+)", code, flags=re.I)
        if radix_match:
            CURRENT_RADIX = int(radix_match.group(1))
        if re.match(r"\s*[A-Za-z_.$?][\w.$?]*\s+MACRO\b", code, flags=re.I):
            in_macro_block = True
            continue
        converted = convert_instruction(code.rstrip())
        if converted:
            if comment and not converted.startswith(";"):
                converted = converted + " " + comment
            out.extend(converted.splitlines())
        elif comment:
            out.append(comment)
    dst.write_text("\n".join(out) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("src", type=Path)
    parser.add_argument("dst", type=Path)
    args = parser.parse_args()
    convert_file(args.src, args.dst)


if __name__ == "__main__":
    main()

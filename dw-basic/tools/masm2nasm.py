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
DATA_SYMBOLS: set[str] = set()
ASSIGNMENT_COUNTS: dict[str, int] = {}
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
    "AND",
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
    "OR",
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
    "XOR",
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


def convert_masm_boolean_operators(text: str) -> str:
    def convert_part(part: str) -> str:
        part = re.sub(r"\bOR\b", "|", part, flags=re.I)
        part = re.sub(r"\bAND\b", "&", part, flags=re.I)
        return part

    return "".join(chunk if quoted else convert_part(chunk) for quoted, chunk in split_quoted(text))


def expr_has_location_counter(text: str) -> bool:
    return re.search(r"(?<![A-Za-z0-9_?])\$(?![A-Za-z_?])", text) is not None


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


def collect_data_symbols(src: Path) -> set[str]:
    symbols: set[str] = set()
    in_data_segment = False
    for line in src.read_text(errors="replace").splitlines():
        code, _comment = split_comment(line)
        stripped = code.strip()
        upper = stripped.upper()

        if upper.endswith("SEGMENT PUBLIC 'DATASG'"):
            in_data_segment = True
            continue
        if upper.endswith("SEGMENT PUBLIC 'CODESG'"):
            in_data_segment = False
            continue
        if upper.endswith("ENDS"):
            in_data_segment = False
            continue
        if not in_data_segment:
            continue

        m = re.match(r"EXTRN\s+(.+)$", stripped, flags=re.I)
        if m:
            for item in m.group(1).split(","):
                raw_name = item.strip().split(":")[0].strip()
                if raw_name and not is_absolute_name(raw_name):
                    symbols.add(rename_symbol(raw_name).upper())
            continue

        m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s*:\s*(DB|DW|DD)?\b", stripped, flags=re.I)
        if m:
            symbols.add(rename_symbol(m.group(1)).upper())
            continue

        m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s+(DB|DW|DD)\b", stripped, flags=re.I)
        if m:
            symbols.add(rename_symbol(m.group(1)).upper())

    return symbols


def collect_assignment_counts(src: Path) -> dict[str, int]:
    counts: dict[str, int] = {}
    for line in src.read_text(errors="replace").splitlines():
        code, _comment = split_comment(line)
        stripped = code.strip()
        m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s*=\s*(.+)$", stripped)
        if m:
            name = rename_symbol(m.group(1)).upper()
            counts[name] = counts.get(name, 0) + 1
    return counts


def split_operands(text: str) -> list[str]:
    operands: list[str] = []
    start = 0
    bracket_depth = 0
    in_string = False
    for i, ch in enumerate(text):
        if ch == '"':
            in_string = not in_string
        elif not in_string:
            if ch == "[":
                bracket_depth += 1
            elif ch == "]" and bracket_depth:
                bracket_depth -= 1
            elif ch == "," and bracket_depth == 0:
                operands.append(text[start:i].strip())
                start = i + 1
    operands.append(text[start:].strip())
    return operands


def first_symbol_name(text: str) -> str | None:
    m = re.search(r"[A-Za-z_.$?][\w.$?]*", text)
    if not m:
        return None
    return rename_symbol(m.group(0)).upper()


def masm_operand_is_data_memory(original_operand: str) -> bool:
    operand = original_operand.strip()
    if not operand:
        return False
    if re.search(r"\bOFFSET\b", operand, flags=re.I):
        return False
    if "[" in operand or "]" in operand:
        return False
    operand = re.sub(r"\b(BYTE|WORD|DWORD)\s+PTR\b", "", operand, flags=re.I).strip()
    if operand.lower() in REGISTERS:
        return False
    if operand.startswith('"') or re.fullmatch(r"[0-9]+[DO]?", operand, flags=re.I):
        return False
    symbol = first_symbol_name(operand)
    return symbol in DATA_SYMBOLS if symbol else False


def wrap_data_memory_operand(converted_operand: str) -> str:
    operand = converted_operand.strip()
    prefix = ""
    m = re.match(r"(?i)^(byte|word|dword)\s+(.+)$", operand)
    if m:
        prefix = m.group(1).lower() + " "
        operand = m.group(2).strip()
    if operand.startswith("[") or operand.lower() in REGISTERS:
        return converted_operand
    return prefix + "[" + operand + "]"


def wrap_masm_data_memory_operands(original_body: str, converted_code: str) -> str:
    original_match = re.match(r"([A-Za-z][A-Za-z0-9]*)\s+(.+)$", original_body.strip())
    if not original_match:
        return converted_code
    op = original_match.group(1).upper()
    if op not in {"MOV", "ADD", "ADC", "SUB", "SBB", "CMP", "XCHG", "OR", "AND", "XOR", "TEST"}:
        return converted_code
    original_operands = split_operands(original_match.group(2))
    if not any(masm_operand_is_data_memory(operand) for operand in original_operands):
        return converted_code

    converted_match = re.match(r"(\s*(?:[A-Za-z_.$?][\w.$?]*:\s*)?)\s*([A-Za-z][A-Za-z0-9]*)\s+(.+)$", converted_code)
    if not converted_match:
        return converted_code
    converted_operands = split_operands(converted_match.group(3))
    if len(converted_operands) != len(original_operands):
        return converted_code

    for i, original_operand in enumerate(original_operands):
        if masm_operand_is_data_memory(original_operand):
            converted_operands[i] = wrap_data_memory_operand(converted_operands[i])

    return converted_match.group(1) + converted_match.group(2) + " " + ", ".join(converted_operands)


def normalize_masm_indexed_memory_syntax(code: str) -> str:
    code = re.sub(
        r"\b(byte|word|dword)\s+\[([A-Za-z_.$?][\w.$?]*)\]\s*\+\s*\[([^\]]+)\]",
        r"\1 [\2+\3]",
        code,
        flags=re.I,
    )
    code = re.sub(
        r"\b(byte|word|dword)\s+\[([A-Za-z_.$?][\w.$?]*)\]\s*-\s*\[([^\]]+)\+([0-9]+|0o[0-7]+)\]",
        r"\1 [\2+\3-\4]",
        code,
        flags=re.I,
    )
    code = re.sub(
        r"\b(byte|word|dword)\s+\[([A-Za-z_.$?][\w.$?]*)\]\[([^\]]+)\]",
        r"\1 [\2+\3]",
        code,
        flags=re.I,
    )
    return code


def convert_instruction_operand_boolean_operators(code: str) -> str:
    m = re.match(r"(\s*(?:(?:[A-Za-z_.$?][\w.$?]*:)\s*)?)([A-Za-z][A-Za-z0-9]*)\b(.*)$", code)
    if not m:
        return code
    op = m.group(2).upper()
    if op not in {"MOV", "ADD", "ADC", "SUB", "SBB", "CMP", "XCHG", "PUSH", "TEST"}:
        return code
    return m.group(1) + m.group(2) + convert_masm_boolean_operators(m.group(3))


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
    if upper in {".SALL", ".XLIST", ".LIST", "PAGE", "END"} or re.match(r"END\s+", stripped, flags=re.I):
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
        raw_expr = m.group(2).strip()
        expr = convert_masm_boolean_operators(convert_expr(raw_expr))
        if expr_has_location_counter(raw_expr) and not (raw_expr == "$" and ASSIGNMENT_COUNTS.get(name.upper(), 0) > 1):
            return name + " equ " + expr
        if name in {"DATAS", "FORSZC"}:
            return name + " equ " + expr
        if re.search(rf"\b{re.escape(name)}\b", expr):
            return "%assign " + name + " " + expr
        if re.fullmatch(r"[0-9]+", expr):
            return "%assign " + name + " " + expr
        if expr == "_OFFST":
            return "%xdefine " + name + " " + expr
        return "%define " + name + " " + expr

    m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s+EQU\s+(.+)$", stripped, flags=re.I)
    if m:
        expr = convert_masm_boolean_operators(convert_expr(m.group(2).strip()))
        return rename_symbol(m.group(1)) + " equ " + expr

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
            lines = [label + "db " + convert_octal_byte(args[0])]
            if args[1]:
                lines.append("db " + convert_octal_byte(args[1]))
            lines.append("dw " + convert_expr(args[2]))
            return "\n".join(lines)
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

    m = re.match(r"([A-Za-z_.$?][\w.$?]*)\s+PROC\b", body, flags=re.I)
    if m:
        return label + rename_symbol(m.group(1)) + ":"

    if re.match(r"[A-Za-z_.$?][\w.$?]*\s+ENDP\b", body, flags=re.I):
        return ""

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

    translated_macros = {
        "HLFDE": "shr dx, 1",
        "HLFHL": "shr bx, 1",
        "NEGDE": "neg dx",
        "NEGHL": "neg bx",
    }
    if body.upper() in translated_macros:
        return label + translated_macros[body.upper()]

    # Common instruction expression fixes.
    code = convert_expr(code)
    code = convert_instruction_operand_boolean_operators(code)
    code = re.sub(r"\bMOV\s+CH,\s*CNSLEN\+3\b", "mov cx, CNSLEN+3\nmov ch, cl", code, flags=re.I)
    code = re.sub(r"\bXLAT\s+BYTE PTR\s+\?CSLAB\b", "cs xlatb", code, flags=re.I)
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
    code = normalize_masm_indexed_memory_syntax(code)
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
    code = wrap_masm_data_memory_operands(body, code)
    code = normalize_masm_indexed_memory_syntax(code)
    return code


def convert_file(src: Path, dst: Path, initial_radix: int = 10) -> None:
    global CURRENT_RADIX, DATA_SYMBOLS, ASSIGNMENT_COUNTS
    dst.parent.mkdir(parents=True, exist_ok=True)
    out: list[str] = [
        "; Auto-converted mechanically from " + str(src),
        "; Edit the converter or the generated source deliberately; do not hand-wave syntax changes.",
        "",
    ]
    in_comment_block: str | None = None
    in_macro_block = False
    CURRENT_RADIX = initial_radix
    DATA_SYMBOLS = collect_data_symbols(src)
    ASSIGNMENT_COUNTS = collect_assignment_counts(src)
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
    dst.write_text("\n".join(line.rstrip() for line in out) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--initial-radix",
        type=int,
        choices=(8, 10),
        default=10,
        help="initial MASM radix before the first .RADIX directive; use 8 for sources inheriting a prior .RADIX 8",
    )
    parser.add_argument("src", type=Path)
    parser.add_argument("dst", type=Path)
    args = parser.parse_args()
    convert_file(args.src, args.dst, initial_radix=args.initial_radix)


if __name__ == "__main__":
    main()

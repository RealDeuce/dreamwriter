#!/usr/bin/env bash
set -euo pipefail

DOCS=("docs/disassembly/*.md")
QUEUE="docs/disassembly/README.md"
OPEN_ONLY=0
DOCS_SET=0

usage() {
  cat <<'USAGE'
Usage: tools/disasm-validate.sh [--docs <glob> ...] [--queue <file>] [--open-only]

Run disassembly validation checks:
  1) xref-scan for unresolved TODO-xref markers
  2) queue-audit for Root Expansion Queue status

Options:
  --docs <glob>    Markdown docs/glob to include (repeatable). Default: docs/disassembly/*.md
  --queue <file>   Queue file path. Default: docs/disassembly/README.md
  --open-only      In queue-audit, show only open queue roots
  -h, --help       Show this help message
USAGE
}

while (($# > 0)); do
  case "$1" in
    --docs)
      if (($# < 2)); then
        echo "missing argument for --docs" >&2
        exit 2
      fi
      if (( DOCS_SET == 0 )); then
        DOCS=()
        DOCS_SET=1
      fi
      DOCS+=("$2")
      shift 2
      ;;
    --queue)
      if (($# < 2)); then
        echo "missing argument for --queue" >&2
        exit 2
      fi
      QUEUE="$2"
      shift 2
      ;;
    --open-only)
      OPEN_ONLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

FAIL=0

expand_docs=()
for spec in "${DOCS[@]}"; do
  shopt -s nullglob
  for path in $spec; do
    expand_docs+=("$path")
  done
done

echo "==> xref-scan"
XREF_DOCS=()
for doc in "${expand_docs[@]}"; do
  if [[ "$(basename "$doc")" != "README.md" ]]; then
    XREF_DOCS+=("$doc")
  fi
done
if ! tools/rom2.py xref-scan --format text "${XREF_DOCS[@]}"; then
  FAIL=1
fi

echo
echo "==> snippet-bytes"
if ! python3 tools/validate_snippets.py "${DOCS[@]}"; then
  FAIL=1
fi

echo
echo "==> queue-audit"
if ! tools/rom2.py queue-audit --queue "$QUEUE" --scope-docs "${expand_docs[@]}" $([[ "${OPEN_ONLY}" -eq 1 ]] && echo "--open-only"); then
  FAIL=1
fi

if (( FAIL == 0 )); then
  echo
  echo "validation: PASS"
  exit 0
fi

echo
echo "validation: FAIL"
exit 1

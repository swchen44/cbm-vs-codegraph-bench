#!/usr/bin/env bash
# basic.sh - basic C construct extraction comparison: struct/enum/enumerator/function/inline/typedef.
# Complements bench.sh (which focuses on hard cases: fnptr/macro/#ifdef).
# Usage: bench/basic.sh <nick>   (run bench.sh <repo> <nick> first to produce the two DBs)
set -uo pipefail
source "$(dirname "$0")/lib.sh"
NICK="${1:?nick}"; RAW="$ROOT/results/raw/$NICK"; OUT="$ROOT/results/$NICK"
CBMDB=$(ls "$RAW/cbm-cache"/*.db | head -1)
CGDB="$RAW/cg-copy/.codegraph/codegraph.db"
cn(){ sqlite3 "$CBMDB" "SELECT COUNT(*) FROM nodes WHERE label='$1';" 2>/dev/null; }
gn(){ sqlite3 "$CGDB" "SELECT COUNT(*) FROM nodes WHERE kind='$1';" 2>/dev/null; }

# inline recall (sample 20)
GT=$(grep -rhoE "static inline [a-zA-Z_][a-zA-Z0-9_ *]*[ *]([a-z_][a-z0-9_]*)[(]" "$ROOT/repos/wpa_supplicant" --include="*.h" 2>/dev/null | grep -oE "[a-z_][a-z0-9_]*[(]$" | tr -d '(' | sort -u)
tot=0; hc=0; hg=0
for fn in $(printf '%s\n' "$GT" | head -20); do
  tot=$(( tot + 1 ))
  [ -n "$(sqlite3 "$CBMDB" "SELECT 1 FROM nodes WHERE name='$fn' AND label='Function' LIMIT 1;" 2>/dev/null)" ] && hc=$(( hc + 1 ))
  [ -n "$(sqlite3 "$CGDB" "SELECT 1 FROM nodes WHERE name='$fn' AND kind='function' LIMIT 1;" 2>/dev/null)" ] && hg=$(( hg + 1 ))
done

{
  echo "# Basic C construct extraction - $NICK"
  echo
  echo "| construct | cbm (label: count) | codegraph (kind: count) | note |"
  echo "|---|---|---|---|"
  echo "| struct | Class: $(cn Class) | struct: $(gn struct) | cbm has no C Struct label, lumps into Class, count inflated (dups/fwd-decl) |"
  echo "| enum name | Enum: $(cn Enum) | enum: $(gn enum) | both extract |"
  echo "| enumerator (enum value) | none (in Variable: $(cn Variable)) | enum_member: $(gn enum_member) | codegraph dedicated node; cbm treats enum value as variable |"
  echo "| function | Function: $(cn Function) | function: $(gn function) | both near-identical, reliable |"
  echo "| method | Method: $(cn Method) | method: $(gn method) | - |"
  echo "| typedef | none | type_alias: $(gn type_alias) | codegraph yes, cbm no |"
  echo "| macro | Macro: $(cn Macro) | $(gn macro) | cbm extracts macros, codegraph does not |"
  echo
  echo "## inline function recall (static inline in headers)"
  echo "- sample $tot inline functions: cbm $hc / $tot ; codegraph $hg / $tot (both index inline as function)"
  echo
  echo "## known differences / caveats"
  echo "- cbm name collision: e.g. wpa_supplicant is simultaneously struct(Class)/dir(Folder)/function; queries need label filter."
  echo "- codegraph models C types more finely (struct / enum_member / type_alias distinct); cbm is coarser (struct->Class, enum-value->Variable, no typedef label)."
} > "$OUT/basic-constructs.md"
echo "wrote $OUT/basic-constructs.md"

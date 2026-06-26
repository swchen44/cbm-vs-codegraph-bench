#!/usr/bin/env bash
# score.sh - rigorous recall scoring vs neutral ground truth (grep defs + cflow call graph).
# Usage: bench/score.sh <nick>   (run bench.sh first)
set -uo pipefail
source "$(dirname "$0")/lib.sh"
NICK="${1:?nick}"; RAW="$ROOT/results/raw/$NICK"; OUT="$ROOT/results/$NICK"; WPA="$ROOT/repos/wpa_supplicant"
CBMDB=$(ls "$RAW/cbm-cache"/*.db | head -1)
CGDB="$RAW/cg-copy/.codegraph/codegraph.db"

# --- ground truth construct names (grep defs) ---
grep -rhoE "^struct [a-z_][a-z0-9_]*" "$WPA/src" "$WPA/wpa_supplicant" --include="*.h" --include="*.c" 2>/dev/null | awk '{print $2}' | sort -u > /tmp/gt_struct.txt
grep -rhoE "^enum [a-z_][a-z0-9_]*"   "$WPA/src" "$WPA/wpa_supplicant" --include="*.h" --include="*.c" 2>/dev/null | awk '{print $2}' | sort -u > /tmp/gt_enum.txt
grep -rhoE "^[a-z_][a-z0-9_ \*]*[ \*]([a-z_][a-z0-9_]*)\(" "$WPA/src/drivers" "$WPA/src/utils" --include="*.c" 2>/dev/null | grep -oE "[a-z_][a-z0-9_]*\($" | tr -d '(' | grep -vE "^(if|for|while|switch|return|sizeof)$" | sort -u > /tmp/gt_func.txt

sqlite3 "$CBMDB" "SELECT DISTINCT name FROM nodes WHERE label='Class';"   > /tmp/cbm_struct.txt
sqlite3 "$CBMDB" "SELECT DISTINCT name FROM nodes WHERE label='Enum';"    > /tmp/cbm_enum.txt
sqlite3 "$CBMDB" "SELECT DISTINCT name FROM nodes WHERE label='Function';"> /tmp/cbm_func.txt
sqlite3 "$CGDB"  "SELECT DISTINCT name FROM nodes WHERE kind='struct';"   > /tmp/cg_struct.txt
sqlite3 "$CGDB"  "SELECT DISTINCT name FROM nodes WHERE kind='enum';"     > /tmp/cg_enum.txt
sqlite3 "$CGDB"  "SELECT DISTINCT name FROM nodes WHERE kind='function';" > /tmp/cg_func.txt

# --- cflow call graph ground truth (3 self-contained files) ---
cflow --depth=2 "$WPA/src/utils/eloop.c" "$WPA/src/utils/common.c" "$WPA/src/drivers/driver_common.c" 2>/dev/null > /tmp/cflow.txt
sqlite3 "$CBMDB" "SELECT s.name||'>'||t.name FROM edges e JOIN nodes s ON s.id=e.source_id JOIN nodes t ON t.id=e.target_id WHERE e.type='CALLS';" > /tmp/cbm_calls.txt
sqlite3 "$CGDB"  "SELECT s.name||'>'||t.name FROM edges e JOIN nodes s ON s.id=e.source     JOIN nodes t ON t.id=e.target     WHERE e.kind='calls';" > /tmp/cg_calls.txt
# call-edge source granularity
CBM_FN=$(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM edges e JOIN nodes s ON s.id=e.source_id WHERE e.type='CALLS' AND s.label IN ('Function','Method');")
CBM_ALL=$(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM edges WHERE type='CALLS';")
CG_FN=$(sqlite3 "$CGDB" "SELECT COUNT(*) FROM edges e JOIN nodes s ON s.id=e.source WHERE e.kind='calls' AND s.kind IN ('function','method');")
CG_ALL=$(sqlite3 "$CGDB" "SELECT COUNT(*) FROM edges WHERE kind='calls';")

python3 - "$CBM_FN" "$CBM_ALL" "$CG_FN" "$CG_ALL" <<'PY' > "$OUT/scorecard.md"
import re,sys
cbm_fn,cbm_all,cg_fn,cg_all=map(int,sys.argv[1:5])
def load(p):
    try:return set(l.strip() for l in open(p) if l.strip())
    except:return set()
def rec(g,o):
    g=load(g);o=load(o);h=len(g&o);return h,len(g),(100*h/len(g) if g else 0)
print("# Scorecard - rigorous recall vs neutral ground truth\n")
print("## 1. 基本建構召回率 (vs grep 定義)")
print("| 建構 | GT | cbm 召回 | codegraph 召回 |")
print("|---|---|---|---|")
for nm,gt,c,g in [("struct","/tmp/gt_struct.txt","/tmp/cbm_struct.txt","/tmp/cg_struct.txt"),
                  ("enum","/tmp/gt_enum.txt","/tmp/cbm_enum.txt","/tmp/cg_enum.txt"),
                  ("function","/tmp/gt_func.txt","/tmp/cbm_func.txt","/tmp/cg_func.txt")]:
    ch,n,cp=rec(gt,c); gh,_,gp=rec(gt,g)
    print(f"| {nm} | {n} | {ch} ({cp:.0f}%) | {gh} ({gp:.0f}%) |")
# call graph
edges=set();internal=set();caller=None
for line in open('/tmp/cflow.txt'):
    if not line.strip():continue
    ind=len(line)-len(line.lstrip())
    m=re.match(r'\s*([A-Za-z_]\w*)\(\)',line)
    if not m:continue
    nm=m.group(1);res='<' in line and ' at ' in line
    if ind==0:caller=nm;internal.add(nm)
    elif ind>=4 and caller:
        if res:internal.add(nm)
        edges.add((caller,nm))
gt=set((c,e) for c,e in edges if e in internal and c!=e)
cbm=set(tuple(l.strip().split('>',1)) for l in open('/tmp/cbm_calls.txt') if '>' in l)
cg=set(tuple(l.strip().split('>',1)) for l in open('/tmp/cg_calls.txt') if '>' in l)
ch=len(gt&cbm);gh=len(gt&cg);n=len(gt)
print("\n## 2. 直接呼叫圖召回率 (vs cflow 中立 ground truth, 3 檔)")
print("| 工具 | 命中/GT | 召回 |")
print("|---|---|---|")
print(f"| cbm | {ch}/{n} | {100*ch/n:.0f}% |")
print(f"| codegraph | {gh}/{n} | {100*gh/n:.0f}% |")
print("\n## 3. 呼叫邊「來源粒度」(★根因)")
print("| 工具 | 函式級 CALLS source | 佔比 |")
print("|---|---|---|")
print(f"| cbm | {cbm_fn} / {cbm_all} | **{100*cbm_fn/cbm_all:.1f}%** (其餘掛在 Module/檔案) |")
print(f"| codegraph | {cg_fn} / {cg_all} | **{100*cg_fn/cg_all:.1f}%** |")
print("\n> cbm 的 CALLS 邊 ~99% 來源是『檔案(Module)』而非『呼叫函式』，故函式級『誰呼叫誰』查詢幾乎全空——這是 cbm 在此 C 專案的根本限制，非單純函式指標問題。")
print("\n## 4. 函式指標分派召回 (.scan2，見 REPORT 3.3)")
print("- codegraph 3/5 (60%)｜cbm 0/5")
PY
echo "wrote $OUT/scorecard.md"; cat "$OUT/scorecard.md"

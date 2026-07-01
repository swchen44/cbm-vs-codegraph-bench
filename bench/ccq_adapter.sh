#!/usr/bin/env bash
# ccq_adapter.sh — add ccq (Go + clangd + fnptr synthesizer) as a first-class
# contestant, scored against the SAME neutral ground truth as score.sh:
#   - direct call-graph recall vs cflow (3 self-contained files)
#   - fn-pointer .scan2 dispatch recall (the 5 wpa_driver_ops handlers)
#   - index time + setup cost
# ccq is queried per ground-truth symbol (no whole-repo export needed), so this
# is fast and directly comparable. Reproducible: raw outputs land in results/.
#
# Usage: bench/ccq_adapter.sh <repo_path> <nick>
#   e.g. bench/ccq_adapter.sh repos/wpa_supplicant wpa
# Env: CCQ_SRC (ccq checkout, default ~/git/ccq), CCQ_BIN (prebuilt binary).
set -uo pipefail
source "$(dirname "$0")/lib.sh"
REPO="$(cd "${1:?repo}" && pwd)"; NICK="${2:?nick}"
OUT="$ROOT/results/$NICK"; RAW="$ROOT/results/raw/$NICK"; mkdir -p "$OUT" "$RAW"

# Ground truth is per-repo. Defaults target wpa_supplicant; override for others.
#   CG_GT    — 3 self-contained files for the cflow call-graph GT (repo-relative)
#   FNPTR_GT — fn-pointer handler names (set empty to skip the fnptr section)
CG_GT="${CG_GT:-src/utils/eloop.c src/utils/common.c src/drivers/driver_common.c}"
FNPTR_GT="${FNPTR_GT-driver_nl80211_scan2 wpa_driver_bsd_scan wpa_driver_ndis_scan wpa_driver_privsep_scan wpa_driver_wext_scan}"

# --- build ccq (or use CCQ_BIN) ---
CCQ_BIN="${CCQ_BIN:-}"
if [ -z "$CCQ_BIN" ]; then
  CCQ_SRC="${CCQ_SRC:-$HOME/git/ccq}"
  CCQ_BIN="$RAW/ccq"
  echo "building ccq from $CCQ_SRC ..."
  ( cd "$CCQ_SRC" && go build -o "$CCQ_BIN" ./cmd/ccq ) || { echo "ccq build failed"; exit 1; }
fi
echo "ccq: $("$CCQ_BIN" version 2>/dev/null || echo '?')"

pkill -f clangd 2>/dev/null; sleep 1

# --- index (warm the daemon), timed ---
echo "==== ccq index $NICK ===="
/usr/bin/time -l "$CCQ_BIN" wait-index -p "$REPO" > "$RAW/ccq-index.log" 2>&1
CCQ_T=$(awk '/real/{print $1"s"}' "$RAW/ccq-index.log" | head -1)
CCQ_M=$(awk '/maximum resident/{printf "%.0fMB",$1/1048576}' "$RAW/ccq-index.log" | head -1)
if grep -q 'no-build' "$RAW/ccq-index.log"; then CCQ_MODE="no-build (compile_flags.txt)"; else CCQ_MODE="compile_commands"; fi

# --- direct call-graph recall vs cflow (same GT as score.sh) ---
GT_ARGS=(); for f in $CG_GT; do GT_ARGS+=("$REPO/$f"); done
cflow --depth=2 "${GT_ARGS[@]}" 2>/dev/null > "$RAW/cflow.txt"

# GT callees (internal), then query ccq callers for each and record hits.
python3 - "$CCQ_BIN" "$REPO" "$RAW" <<'PY' > "$OUT/ccq-callgraph.tmp"
import re,sys,subprocess,json
ccq,repo,raw=sys.argv[1],sys.argv[2],sys.argv[3]
edges=set();internal=set();caller=None
for line in open(raw+'/cflow.txt'):
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
# query ccq callers once per unique callee (warm daemon)
callers={}
for e in sorted({e for _,e in gt}):
    try:
        out=subprocess.run([ccq,"callers",e,"-p",repo,"--json"],capture_output=True,text=True,timeout=120).stdout
        callers[e]=set(json.loads(out).get("callers",[]))
    except Exception:
        callers[e]=set()
hit=sum(1 for c,e in gt if c in callers.get(e,set()))
print(f"{hit}\t{len(gt)}")
PY
read CCQ_CG_HIT CCQ_CG_GT < "$OUT/ccq-callgraph.tmp" || true; rm -f "$OUT/ccq-callgraph.tmp"
: "${CCQ_CG_HIT:=0}" "${CCQ_CG_GT:=0}"

# --- fn-pointer .scan2 recall (wpa_driver_ops handlers); skipped if FNPTR_GT empty ---
fn_hit=0; fn_n=0
for h in $FNPTR_GT; do
  fn_n=$((fn_n+1))
  n=$("$CCQ_BIN" callers "$h" -p "$REPO" 2>/dev/null | grep -c 'scan2')
  [ "$n" -gt 0 ] && fn_hit=$((fn_hit+1))
done

pkill -f clangd 2>/dev/null

# --- scorecard ---
cg_pct=$(python3 -c "print(f'{100*$CCQ_CG_HIT/$CCQ_CG_GT:.0f}' if $CCQ_CG_GT else '0')")
fn_pct=$(python3 -c "print(f'{100*$fn_hit/$fn_n:.0f}' if $fn_n else '0')")
CCQ_LABEL="ccq (${CCQ_MODE%% *})" # ccq (no-build) | ccq (compile_commands)
{
  echo "# ccq scorecard — $NICK (vs the same neutral ground truth)"
  echo
  echo "> ccq $("$CCQ_BIN" version 2>/dev/null) | mode: $CCQ_MODE | index $CCQ_T / RAM $CCQ_M"
  echo
  echo "## 1. 直接呼叫圖召回 (vs cflow) — 對照 cbm / CodeGraph 見 REPORT"
  echo "| 工具 | 命中/GT | 召回 |"
  echo "|---|---|---|"
  echo "| **$CCQ_LABEL** | **$CCQ_CG_HIT/$CCQ_CG_GT** | **${cg_pct}%** |"
  echo
  if [ "$fn_n" -gt 0 ]; then
    echo "## 2. 函式指標 .scan2 分派召回 — 對照 cbm 0/5 / CodeGraph 3/5"
    echo "| 工具 | 命中/GT | 召回 |"
    echo "|---|---|---|"
    echo "| **$CCQ_LABEL** | **$fn_hit/$fn_n** | **${fn_pct}%** |"
    echo "| CodeGraph | 3/5 | 60% (REPORT) |"
    echo "| cbm | 0/5 | 0% (REPORT) |"
    echo
  fi
  echo "## 3. 呼叫邊粒度"
  echo "- ccq: **100% 函式級**（所有 CALLS 邊來自 clangd incomingCalls，天生 function→function）— 對照 cbm 1.0% / CodeGraph 100%。"
  echo
  echo "## 4. Setup 成本"
  echo "- ccq 需 \`compile_flags.txt\`(no-build,\`ccq init\` 自動產)或 \`compile_commands.json\`；本次 mode = ${CCQ_MODE}。"
  echo "- cbm / CodeGraph 免 build（tree-sitter），但函式級呼叫圖召回 0% / 93%（見上）。"
} > "$OUT/ccq-scorecard.md"
echo "wrote $OUT/ccq-scorecard.md"; cat "$OUT/ccq-scorecard.md"

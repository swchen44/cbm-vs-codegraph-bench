#!/usr/bin/env bash
# bench.sh — 主 harness：索引兩工具 + 結構指標 + 考題 Q1-Q6 + 結構性能。
# 用法：bench/bench.sh <repo_path> <nick>   例：bench/bench.sh repos/wpa_supplicant full
# 設計原則（沿用 win4r headtohead.sh）：deterministic、用中立 grep/cscope 當錨、客觀指標。
set -uo pipefail
source "$(dirname "$0")/lib.sh"
REPO="$(cd "${1:?repo}" && pwd)"; NICK="${2:?nick}"
OUT="$ROOT/results/$NICK"; RAW="$ROOT/results/raw/$NICK"; mkdir -p "$OUT" "$RAW"
CBM_CACHE="$RAW/cbm-cache"; mkdir -p "$CBM_CACHE"

echo "==== 索引 $NICK ($(find "$REPO" -name '*.c' -o -name '*.h' | wc -l | tr -d ' ') C/H 檔) ===="

# --- cbm 索引（計時） ---
/usr/bin/time -l env CBM_CACHE_DIR="$CBM_CACHE" "$CBM" --json cli index_repository \
  "{\"repo_path\":\"$REPO\",\"mode\":\"full\"}" > "$RAW/cbm-index.json" 2> "$RAW/cbm-time.log"
PROJ=$(cbm_proj "$CBM_CACHE"); CBMDB="$CBM_CACHE/$PROJ.db"

# --- codegraph 索引（計時，就地，需獨立複本避免污染） ---
CG="$RAW/cg-copy"; rm -rf "$CG"; cp -R "$REPO" "$CG"
/usr/bin/time -l codegraph init "$CG" > "$RAW/cg-index.log" 2>&1
CGDB="$CG/.codegraph/codegraph.db"

# --- 結構指標 ---
{
  echo "# 結構指標 — $NICK"
  echo "## 規模"
  echo "| 工具 | nodes | edges | 索引耗時 | RAM峰值 |"
  echo "|---|---|---|---|---|"
  CBM_N=$(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM nodes;"); CBM_E=$(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM edges;")
  CG_N=$(sqlite3 "$CGDB" "SELECT COUNT(*) FROM nodes;"); CG_E=$(sqlite3 "$CGDB" "SELECT COUNT(*) FROM edges;")
  CBM_T=$(awk '/real/{print $1"s"}' "$RAW/cbm-time.log" | head -1)
  CG_T=$(awk '/real/{print $1"s"}' "$RAW/cg-index.log" | head -1)
  CBM_M=$(awk '/maximum resident/{printf "%.0fMB",$1/1048576}' "$RAW/cbm-time.log" | head -1)
  CG_M=$(awk '/maximum resident/{printf "%.0fMB",$1/1048576}' "$RAW/cg-index.log" | head -1)
  echo "| cbm | $CBM_N | $CBM_E | $CBM_T | $CBM_M |"
  echo "| codegraph | $CG_N | $CG_E | $CG_T | $CG_M |"
  echo
  echo "## cbm 節點 label 分布"; echo '```'
  sqlite3 "$CBMDB" "SELECT label,COUNT(*) FROM nodes GROUP BY label ORDER BY COUNT(*) DESC;"; echo '```'
  echo "## codegraph 節點 kind 分布"; echo '```'
  sqlite3 "$CGDB" "SELECT kind,COUNT(*) FROM nodes GROUP BY kind ORDER BY COUNT(*) DESC;"; echo '```'
  echo "## 函式指標合成邊（codegraph 專有）"
  FN=$(sqlite3 "$CGDB" "SELECT COUNT(*) FROM edges WHERE json_extract(metadata,'\$.synthesizedBy')='fn-pointer-dispatch';")
  echo "- codegraph fn-pointer-dispatch 合成邊: **$FN**"
  echo "- cbm 對應合成: 無（cbm 不合成函式指標分派邊）"
  echo "## 巨集節點"
  echo "- cbm Macro 節點: $(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM nodes WHERE label='Macro';")"
  echo "- codegraph macro 節點: $(sqlite3 "$CGDB" "SELECT COUNT(*) FROM nodes WHERE kind LIKE '%macro%';") (codegraph 不抽巨集)"
} > "$OUT/structural.md"
echo "→ 結構指標寫入 $OUT/structural.md"

# --- 考題 Q1-Q6（原始輸出存 RAW） ---
{
  echo "# 考題結果 — $NICK"
  echo "## Q1 誰呼叫 wpa_driver_wext_scan?（fnptr 分派正向）"
  echo "- codegraph: $(codegraph callers wpa_driver_wext_scan -p "$CG" -j 2>/dev/null | cg_names)"
  echo "- cbm(trace_path): $(cbm_trace "$CBM_CACHE" "$PROJ" wpa_driver_wext_scan inbound | python3 -c "import sys,json;d=json.load(sys.stdin);print(', '.join(c.get('name',str(c)) for c in d.get('callers',[])) or '(空)')" 2>/dev/null)"
  echo "## Q2 wpa_drv_scan 分派到?（fnptr 分派反向，GT: wext_scan/nl80211_scan2/privsep_scan）"
  echo "- codegraph: $(codegraph callees wpa_drv_scan -p "$CG" -j 2>/dev/null | cg_names)"
  echo "- cbm: $(cbm_q "$CBM_CACHE" "$PROJ" "MATCH (a)-[:CALLS]->(b) WHERE a.name='wpa_drv_scan' RETURN b.name" | rows1)"
  echo "## Q3 .scan2 欄位註冊了哪些函式?（候選列舉）"
  echo "- codegraph(合成邊): $(sqlite3 "$CGDB" "SELECT GROUP_CONCAT(DISTINCT t.name) FROM edges e JOIN nodes s ON s.id=e.source JOIN nodes t ON t.id=e.target WHERE json_extract(e.metadata,'\$.synthesizedBy')='fn-pointer-dispatch' AND s.name='wpa_drv_scan';")"
  echo "## Q4 wpa_driver_wext_scan_timeout 誰呼叫?（callback 盲區，GT: 僅註冊點）"
  echo "- codegraph: $(codegraph callers wpa_driver_wext_scan_timeout -p "$CG" -j 2>/dev/null | cg_names)"
  echo "- cbm: $(cbm_q "$CBM_CACHE" "$PROJ" "MATCH (a)-[:CALLS]->(b) WHERE b.name='wpa_driver_wext_scan_timeout' RETURN a.name" | rows1)"
  echo "## Q5 巨集處理（os_memcpy）"
  echo "- cbm Macro 節點 os_memcpy: $(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM nodes WHERE name='os_memcpy' AND label='Macro';")"
  echo "- codegraph os_memcpy 節點: $(sqlite3 "$CGDB" "SELECT COUNT(*) FROM nodes WHERE name='os_memcpy';")"
  echo "## Q6 #ifdef 過度涵蓋（nl80211_mgmt_subscribe_mesh 在 CONFIG 區塊內）"
  echo "- cbm 收錄: $(sqlite3 "$CBMDB" "SELECT COUNT(*) FROM nodes WHERE name='nl80211_mgmt_subscribe_mesh';")"
  echo "- codegraph 收錄: $(sqlite3 "$CGDB" "SELECT COUNT(*) FROM nodes WHERE name='nl80211_mgmt_subscribe_mesh';")"
} > "$OUT/questions.md"
echo "→ 考題結果寫入 $OUT/questions.md"

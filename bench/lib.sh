#!/usr/bin/env bash
# lib.sh — 共用路徑與 helper。source 之。
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
export CODEGRAPH_TELEMETRY=0
CBM="$ROOT/repos/cbm-fork/build/c/codebase-memory-mcp"

# cbm 查詢：query_graph（Cypher），過濾 level= log 行
# 用法：cbm_q <cache_dir> <project> "<cypher>"
cbm_q(){ CBM_CACHE_DIR="$1" "$CBM" cli query_graph "{\"project\":\"$2\",\"query\":\"$3\"}" 2>/dev/null | grep -v '^level='; }
# cbm 原生 trace_path
cbm_trace(){ CBM_CACHE_DIR="$1" "$CBM" cli trace_path "{\"project\":\"$2\",\"function_name\":\"$3\",\"direction\":\"$4\",\"depth\":3}" 2>/dev/null | grep -v '^level='; }
cbm_proj(){ ls "$1"/*.db 2>/dev/null | head -1 | xargs -I{} basename {} .db; }

# 取 JSON rows 第一欄為逗號清單
rows1(){ python3 -c "import sys,json;d=json.load(sys.stdin);print(', '.join(str(r[0]) for r in d.get('rows',[])) or '(空)')" 2>/dev/null; }
# codegraph callers/callees JSON → 名稱清單
cg_names(){ python3 -c "import sys,json;d=json.load(sys.stdin);k='callers' if 'callers' in d else 'callees';print(', '.join(c['name'] for c in d.get(k,[])) or '(空)')" 2>/dev/null; }

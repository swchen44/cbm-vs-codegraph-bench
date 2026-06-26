# C 程式碼分析 Playbook：cbm vs CodeGraph 怎麼選、怎麼用

> 一頁決策指南。實測基礎見 [`REPORT.md`](REPORT.md) 與 [`results/full/scorecard.md`](results/full/scorecard.md)。
> 結論在兩個風格迥異的 C 專案（wpa_supplicant、redis）上一致。

---

## TL;DR 一句話

> **要「呼叫關係」（誰呼叫誰、影響分析、函式指標分派）→ 用 CodeGraph。要「符號/型別清單 + 巨集 + 任意 Cypher 查詢」→ 用 cbm。
> 在 C 上，cbm 幾乎無法做函式級呼叫圖（實測 0–1% 函式級），這是它的硬限制。**

---

## Step 1：30 秒判斷你的 C 專案

```bash
cd your-c-project
echo "函式指標表: $(grep -rhcE 'struct [a-z_]+_ops' --include=*.h . | paste -sd+ | bc 2>/dev/null) 處"
echo "條件編譯:   $(grep -rcE '^\s*#\s*(ifdef|if defined)' --include=*.c --include=*.h . | paste -sd+ | bc 2>/dev/null) 處"
echo "巨集定義:   $(grep -rcE '^\s*#\s*define' --include=*.h . | paste -sd+ | bc 2>/dev/null) 處"
```

| 你的主要問題 | 選誰 |
|-------------|------|
| 「這個函式被誰呼叫 / 它呼叫了誰 / 改了會影響誰」 | **CodeGraph**（cbm 在 C 上答不出來） |
| 「`obj->op()` 實際接到哪個實作」（函式指標分派） | **CodeGraph**（合成器，召回 ~60%，需人工補） |
| 「列出所有 struct / enum / function / 某個符號定義在哪」 | 兩者皆可（召回 85–100%），cbm 的 Cypher 更靈活 |
| 「這個巨集是什麼 / 哪些巨集」 | **cbm**（codegraph 不抽巨集） |
| 「用 Cypher 跑任意圖分析」 | **cbm**（codegraph 無查詢語言） |
| 「最快索引超大 repo」 | **cbm**（Pure C，快 3–4 倍） |

---

## Step 2：安裝（一次）

```bash
# CodeGraph（系統 Node ≥25 時務必用 bundled installer）
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# cbm（要自 build，~3 分鐘；需 clang/gcc，libgit2 可選）
git clone --depth=1 https://github.com/win4r/codebase-memory-mcp-pro
cd codebase-memory-mcp-pro && ./scripts/build.sh
```

## Step 3：索引 + 常用查詢

```bash
# ── CodeGraph（呼叫關係主力）──
codegraph init .
codegraph callers <func> -p . -j        # 誰呼叫
codegraph callees <func> -p . -j        # 呼叫了誰（含函式指標合成邊）
codegraph impact  <func> -d 3 -p . -j   # 影響半徑
codegraph explore "how does X work" -p . # 一句話拿源碼+關聯
# 看函式指標分派合成邊：
sqlite3 .codegraph/codegraph.db \
 "SELECT s.name,t.name FROM edges e JOIN nodes s ON s.id=e.source JOIN nodes t ON t.id=e.target
  WHERE json_extract(e.metadata,'\$.synthesizedBy')='fn-pointer-dispatch';"

# ── cbm（符號清單 + 巨集 + Cypher）──
export CBM_CACHE_DIR=~/.cache/cbm
CBM=.../build/c/codebase-memory-mcp
"$CBM" --json cli index_repository '{"repo_path":"'"$PWD"'","mode":"full"}'
PROJ=$(ls $CBM_CACHE_DIR/*.db | xargs -n1 basename | sed 's/.db$//')
# 列舉某型別/搜尋符號（cbm 強項）：
"$CBM" cli query_graph '{"project":"'"$PROJ"'","query":"MATCH (n:Enum) RETURN n.name LIMIT 50"}'
"$CBM" cli query_graph '{"project":"'"$PROJ"'","query":"MATCH (n:Macro) WHERE n.name CONTAINS \"LOG\" RETURN n.name"}'
```

---

## Step 4：每個工具「能」與「不能」（實測）

| 問題類型 | CodeGraph | cbm |
|---------|-----------|-----|
| 函式級 callers/callees | ✅ ~93% 召回 | ❌ ~0–1%（呼叫圖是檔案級） |
| 函式指標分派 | ⚠️ ~60%（過度近似，列候選） | ❌ 0% |
| callback 延遲呼叫（eloop/timer） | ❌（僅浮出註冊點） | ❌ |
| `#ifdef` 內的碼 | ⚠️ 全收錄（過度涵蓋） | ⚠️ 全收錄 |
| struct/enum/function 清單 | ✅ 85–99%，型別分類精細 | ✅ 90–100%，但 struct→Class、enum 值→Variable |
| 巨集 | ❌ 不抽 | ✅ Macro 節點 |
| 任意 Cypher 查詢 | ❌ | ✅ |

---

## Step 5：哪些「一定要人工複核」

1. **函式指標分派的候選**：CodeGraph 把每個 dispatcher 連到該欄位的每個 handler（過度近似）。用 `grep -rhoE '\.<field>\s*=\s*\w+'` 拿正確註冊清單核對。
2. **callback / 事件迴圈流程**：兩工具都追不到 `eloop_register_timeout(cb)` 之後的呼叫 → 手動讀。
3. **特定 config 的有效碼**：`#ifdef` 兩者都不評估 → 若結論依賴某 `.config`，改用 clangd（吃 `compile_commands.json`）。
4. **cbm 的 name 碰撞**：查 cbm 結果時用 label 限定（同名可能是 struct/folder/function 三種）。

---

## 推薦工作流（多數 C 專案）

```
CodeGraph 為主：索引 → callers/callees/impact/explore 處理所有「呼叫關係」
        ↓ 需要時
cbm 為輔：巨集查詢、符號清單、用 Cypher 做自訂統計
        ↓ 關鍵結論
人工複核：函式指標候選、callback 流程、config 相依
```

# ccq 納入 benchmark 對照

`ccq`（自製，`swchen44/ccq`）= clangd 引擎 + fnptr 啟發式 + 符號編輯 + warm daemon。本頁把 ccq 放進既有對照。

## 8 項 C 語法特性（ctest8）

| # | 特性 | cbm | codegraph | clangd | **ccq** |
|---|------|-----|-----------|--------|---------|
| F1 | 難解 declarator（K&R/回傳fn指標/static/inline） | 節點✅/caller檔案級 | 漏get_op | ✅ | **✅** |
| F2 | typedef 鏈間接呼叫 | ❌ | ❌ | ✅ | **✅** |
| F3 | 巨集生成函式（X-macro） | ❌ | ❌ | ✅ | **✅** |
| F4 | 巨集體內藏呼叫 | ⚠️檔案級 | ❌ | ✅ | **✅** |
| F5 | 跨檔 static 同名 | ✅ | ✅ | ✅ | **✅** |
| F6 | **函式指標分派（ops→handler）** | ❌ | ✅ | ⚠️歸靜態init | **✅✅（fnptr 啟發式）** |
| F7 | `_Generic` 型別分派 | ❌ | ❌ | ✅ | **✅** |
| F8 | forward decl 去重 | ✅ | ✅ | ✅ | **✅** |
| **通過數** | **2** | **3** | **7** | **★8（全過）** |

> **ccq 是唯一 8 項全過的工具**：它拿到 clangd 的全部贏（F1-F5,F7,F8），再用 fnptr 啟發式補上 clangd 唯一輸 codegraph 的 F6。

## 函式級呼叫圖（redis）

| 查詢 | cbm | codegraph | clangd | **ccq** | GT |
|------|-----|-----------|--------|---------|-----|
| 誰呼叫 lookupCommand | 0（檔案級） | 13 | 13 | **13** | 13 |

## 速度（含 warm daemon）

| 工具 | 索引/冷啟 | 暖查詢（重複） |
|------|----------|---------------|
| cbm | 3.8s | 每次重跑（無常駐） |
| codegraph | 11s | 每次重跑 |
| clangd 直驅 | 需先編譯 + 索引 | — |
| **ccq** | 冷 ~30s（啟 daemon+索引一次） | **暖 callers 0.6s / explore 0.07s** |

> ccq 的 warm daemon 讓重複查詢進入**亞秒級**，兼得 clangd 正確性與 cbm 級速度。

## 編輯（Serena 對標）
- `ccq rename t_add t_plus` → 7 edits / 6 檔（dry-run + `--apply`），跨檔安全改名 ✅。

## v0.3 增強（向 codegraph/cbm 各取所長，全程零相依）

| 增強 | 學自 | 結果（受控驗證） |
|------|------|-----------------|
| **fnptr 升級** | codegraph | (struct,field) 複合鍵 → **同名欄位不再跨 struct 污染**（io.read vs stream.read 驗證）；支援 **positional table** `{"add",cmd_add}`；**field←field 傳遞** `h->func=found->fn`。原 F6 仍過。 |
| **無 build 模式** | cbm | `ccq init` 無 build 系統時產 `compile_flags.txt`（掃 -I）→ 無 compile_commands.json 也能**跨檔查詢**（驗證 callers t_add 回完整 7+fnptr）。**零新相依**（不引 tree-sitter）。 |
| **巨集納入 search** | cbm | clangd kind 15 → 顯示 `macro`；`ccq search DEFINE_WRAPPER` 可列。 |
| **graph export** | cbm（代替 Cypher） | `ccq export --format sql\|json`：符號+呼叫圖（calls 用 incomingCalls 建 + fnptr 邊）。`ccq export --format sql\|sqlite3 g.db` 後純 SQL 查（35 節點/20 邊驗證）。**不引 SQLite 相依**。 |

> **取捨**：不做完整 Cypher 引擎（重造 cbm）、不做語意相似邊（破壞零相依、偏離定位）。export 給 80% 的查詢力、零成本。

## 結論
ccq 在 benchmark 上**對齊或贏過** cbm/codegraph/clangd/Serena 的各自強項：
- 函式級呼叫圖 = clangd/codegraph（贏 cbm）
- 8 特性全過（唯一）——尤其 F6 同時擁有 clangd 正確性與 codegraph 的 fnptr 合成
- 速度：warm daemon 亞秒級（對標 cbm）
- 編輯：rename（對標 Serena）
- 內網：Go 零相依單一 binary（贏 Serena 的 ~890 套件 + 下載 clangd）

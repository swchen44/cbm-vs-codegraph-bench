# cbm-vs-codegraph-bench

實測比較 **codebase-memory-mcp-pro**（cbm，win4r fork）與 **CodeGraph** 在 C 程式碼上的能力，
題目為 **wpa_supplicant**（函式指標分派表 + 條件編譯極密集的真實 C 專案）。

## 核心結論
- **函式指標分派**（`drv->ops->scan()`）：CodeGraph 合成器召回 **3/5**，cbm **0/5** → wpa 類 C 用 CodeGraph。
- **巨集 / Cypher 查詢 / 索引速度**：cbm 勝（3,395 Macro 節點、openCypher、4.2s vs 14s）。
- 兩者**互補**。完整分析見 [`REPORT.md`](REPORT.md)。

## 重跑
```bash
./setup.sh                                       # 裝 codegraph(bundled) + build cbm + brew cscope/cflow
bash bench/bench.sh repos/subset subset          # 子集(12檔)驗證方法
bash bench/bench.sh repos/wpa_supplicant full    # 整包(620檔)看規模
```
結果在 `results/{subset,full}/`，原始輸出在 `results/raw/`（已 gitignore 大型 db）。

## 結構
- `setup.sh` — 安裝工具與 clone
- `bench/lib.sh` — 共用 helper
- `bench/bench.sh` — 主 harness（索引兩工具 + 結構指標 + 考題 Q1-Q6）
- `results/subset/SUBSET.md` — 子集檔案與 ground truth
- `REPORT.md` — ★ 完整報告（使用步驟、比較、限制、人類決策）

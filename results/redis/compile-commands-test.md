# compile_commands.json 有/無 對照測試（redis + clangd）

問題：用 `compile_commands.json`（clangd 系 MCP 工具如 Serena/mcp-cpp 的基礎）對函式級呼叫圖差多少？與 tree-sitter 派（codegraph/cbm）比如何？

方法：`bear -- make` 產生 redis 的 `compile_commands.json`（357 TU）。用 `bench/clangd_callers.py` 驅動 clangd 的 `callHierarchy/incomingCalls` 取函式級 callers，移走/還原 `compile_commands.json` 對照。codegraph/cbm 用各自既有索引。

## 四方對比：「誰呼叫 X」的函式級 callers 數

| 受測函式（GT 呼叫所在檔數） | clangd **有** ccjson | clangd **無** ccjson | codegraph (tree-sitter) | cbm (tree-sitter) |
|---|---|---|---|---|
| `lookupCommand`（8 檔） | **13** ✅ | 3 | **13** ✅ | 0 ❌ |
| `lookupKeyRead`（14 檔） | **45** ✅ | 3 | 20 | 0 ❌ |

（clangd「有 ccjson」可視為編譯器級 ground truth。）

## 結論

1. **compile_commands.json 對 clangd 是「決定性」**：沒有它，clangd 退化到只剩**同檔** callers（兩函式都只 3 個，跨檔全失）。有它，clangd 給**完整跨檔函式級**呼叫圖（13、45）。→ **clangd 系 MCP 工具（Serena、mcp-cpp、clangd-mcp-server）若不給 compile_commands.json，幾乎不可用。**
2. **codegraph（tree-sitter、免 build）出乎意料地有競爭力**：`lookupCommand` 與 clangd+ccjson 打平（13/13）；但重度呼叫的 `lookupKeyRead` 只抓到 20/45（~44%），漏掉約一半（可能巨集包裹的呼叫、或未解析的跨檔）。
3. **cbm 函式級全 0**：再次印證其 C 呼叫圖是檔案級。
4. **排序（C 函式級呼叫圖）**：`clangd + compile_commands.json` > `codegraph` > `clangd 無 ccjson` > `cbm`。

## 對你的取捨
- **要最完整/最準的 C 呼叫圖** → clangd 系（Serena / mcp-cpp）+ **必須先產 compile_commands.json**（`bear -- make` 或 CMake `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`）。代價：要可編譯的 build。
- **不想搞 build、要夠用就好** → codegraph（直接呼叫常與 clangd 打平，重度呼叫漏約一半，但零設定）。
- **clangd 沒有 compile_commands.json 時** → 反而比 codegraph 還差（只剩同檔）。所以「裝了 clangd 工具卻不給 compile_commands.json」是最糟組合。

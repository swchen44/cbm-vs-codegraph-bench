# 索引時間 + 傳統工具比較

## 索引/建置時間（同一機器 macOS Apple Silicon）

| 工具 | wpa_supplicant (620 C/H) | redis/src (216 C/H) | 建立的東西 | 能否「誰呼叫誰」 |
|------|--------------------------|---------------------|-----------|------------------|
| **ctags** | 0.08s | 0.04s | 定義 tags | ❌ 只有定義位置 |
| **cscope** | 0.08s | 0.53s | 符號 + 呼叫關係(文字級) | ✅ 函式級(直接呼叫) |
| **cflow** | — | 0.37s | 呼叫圖 | ✅ |
| **cbm** | 4.17s | 3.77s | 語意圖(節點+邊+Macro+semantic) | ⚠️ 檔案級 |
| **codegraph** | 14.02s | 11.09s | 語意圖(節點+邊+fnptr 合成) | ✅ 函式級 |
| **clangd+ccjson** | 需先 `bear -- make`(完整編譯, 數分鐘) + 背景 index | 同左 | 完整編譯器 AST | ✅✅ 最完整 |

> 注意：clangd 的「索引」前提是**整個專案能編譯成功**並產生 compile_commands.json（`bear -- make`），這一步是完整編譯（數分鐘），遠重於其他工具。tree-sitter 派（cbm/codegraph）與傳統工具（ctags/cscope/cflow）皆**不需 build**。

## 傳統工具的呼叫圖能力（實測）

| 查詢 | cscope | codegraph | clangd+ccjson | cbm |
|------|--------|-----------|---------------|-----|
| redis 誰呼叫 lookupCommand（直接呼叫） | **14** | 13 | 13 | 0 |
| wpa 誰呼叫 wpa_driver_wext_scan（**函式指標分派**） | **0** | 3/5 合成 | (runtime 不追) | 0 |

**重點**：
1. **cscope（1970s 工具）對直接呼叫又快又準**：redis lookupCommand 找到 14 個函式級呼叫者（≥ codegraph/clangd），索引只 0.53s。傳統工具是非常強的 baseline。
2. **但 cscope 對函式指標分派同樣失手**（wpa wext_scan = 0）——這印證「間接分派」是**所有純靜態工具**的共同盲區，只有 codegraph 的合成器（過度近似）能部分補上。
3. **速度排序**：ctags ≈ cscope（<0.6s） ≪ cbm（~4s） < codegraph（~11-14s） ≪ clangd（需先完整編譯）。
4. **取捨**：要「快又準的直接呼叫圖且免 build」→ **cscope** 出乎意料是最佳 CP 值；要語意/巨集/Cypher → cbm/codegraph；要最完整含巨集展開/型別/#ifdef → clangd。

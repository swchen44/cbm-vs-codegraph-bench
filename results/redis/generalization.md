# 泛化驗證 — redis（第二 C 專案）

目的：確認「cbm 的 C 呼叫圖是檔案級」不是 wpa_supplicant 特有，而是通用限制。

受測：`redis/src`（216 C/H 檔、~20 萬行）。索引：cbm 3.77s / codegraph ~相近。

## 呼叫圖粒度（★核心驗證）
| 工具 | 函式級 CALLS 佔比 | nodes | edges |
|------|------------------|-------|-------|
| **cbm** | **0 / 8,522 = 0.0%**（全部掛在檔案/Module） | 22,778 | 48,961 |
| **codegraph** | **29,089 / 29,092 = 100.0%** | 8,345 | 39,623 |

對照 wpa：cbm 1.0% / codegraph 98.2%。→ **redis 上 cbm 更極端（0% 函式級）**。

## 具體驗證「誰呼叫 lookupCommand」
- **codegraph**：aclCommand, loadSingleAppendOnlyFile, asmFeedMigrationClient, _serverAssertPrintClientInfo, logCurrentClient, RM_Call ✅（真實函式呼叫者）
- **cbm**：空

## 結論
**cbm 的 C 呼叫圖檔案級是通用限制，非 wpa 特有**。在兩個風格迥異的 C 專案（網路 supplicant vs 記憶體資料庫）上一致：cbm 幾乎無法做函式級「誰呼叫誰」。根因見 REPORT 3.5（`pass_calls.c` enclosing-function 解析失敗 fallback file node）。

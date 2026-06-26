# Scorecard - rigorous recall vs neutral ground truth

## 1. 基本建構召回率 (vs grep 定義)
| 建構 | GT | cbm 召回 | codegraph 召回 |
|---|---|---|---|
| struct | 583 | 526 (90%) | 494 (85%) |
| enum | 219 | 218 (100%) | 217 (99%) |
| function | 1064 | 1030 (97%) | 1052 (99%) |

## 2. 直接呼叫圖召回率 (vs cflow 中立 ground truth, 3 檔)
| 工具 | 命中/GT | 召回 |
|---|---|---|
| cbm | 0/28 | 0% |
| codegraph | 26/28 | 93% |

## 3. 呼叫邊「來源粒度」(★根因)
| 工具 | 函式級 CALLS source | 佔比 |
|---|---|---|
| cbm | 145 / 14958 | **1.0%** (其餘掛在 Module/檔案) |
| codegraph | 41845 / 42621 | **98.2%** |

> cbm 的 CALLS 邊 ~99% 來源是『檔案(Module)』而非『呼叫函式』，故函式級『誰呼叫誰』查詢幾乎全空——這是 cbm 在此 C 專案的根本限制，非單純函式指標問題。

## 4. 函式指標分派召回 (.scan2，見 REPORT 3.3)
- codegraph 3/5 (60%)｜cbm 0/5

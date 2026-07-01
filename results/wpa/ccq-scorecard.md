# ccq scorecard — wpa (vs the same neutral ground truth)

> ccq ccq 0.6.4 | mode: no-build (compile_flags.txt) | index 22.91s / RAM 6MB

## 1. 直接呼叫圖召回 (vs cflow, 3 檔) — 對照 cbm 0% / CodeGraph 93%
| 工具 | 命中/GT | 召回 |
|---|---|---|
| **ccq** | **27/28** | **96%** |
| CodeGraph | 26/28 | 93% (REPORT) |
| cbm | 0/28 | 0% (REPORT) |

## 2. 函式指標 .scan2 分派召回 — 對照 cbm 0/5 / CodeGraph 3/5
| 工具 | 命中/GT | 召回 |
|---|---|---|
| **ccq** | **5/5** | **100%** |
| CodeGraph | 3/5 | 60% (REPORT) |
| cbm | 0/5 | 0% (REPORT) |

## 3. 呼叫邊粒度
- ccq: **100% 函式級**（所有 CALLS 邊來自 clangd incomingCalls，天生 function→function）— 對照 cbm 1.0% / CodeGraph 100%。

## 4. Setup 成本
- ccq 需 `compile_flags.txt`(no-build,`ccq init` 自動產)或 `compile_commands.json`；本次 mode = no-build (compile_flags.txt)。
- cbm / CodeGraph 免 build（tree-sitter），但函式級呼叫圖召回 0% / 93%（見上）。

# ccq scorecard — redis (vs the same neutral ground truth)

> ccq ccq 0.6.4 | mode: compile_commands | index 8.92s / RAM 5MB

## 1. 直接呼叫圖召回 (vs cflow) — 對照 cbm / CodeGraph 見 REPORT
| 工具 | 命中/GT | 召回 |
|---|---|---|
| **ccq (compile_commands)** | **47/73** | **64%** |

## 3. 呼叫邊粒度
- ccq: **100% 函式級**（所有 CALLS 邊來自 clangd incomingCalls，天生 function→function）— 對照 cbm 1.0% / CodeGraph 100%。

## 4. Setup 成本
- ccq 需 `compile_flags.txt`(no-build,`ccq init` 自動產)或 `compile_commands.json`；本次 mode = compile_commands。
- cbm / CodeGraph 免 build（tree-sitter），但函式級呼叫圖召回 0% / 93%（見上）。

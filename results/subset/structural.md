# 結構指標 — subset
## 規模
| 工具 | nodes | edges | 索引耗時 | RAM峰值 |
|---|---|---|---|---|
| cbm | 1468 | 2699 | 0.90s | 109MB |
| codegraph | 923 | 2097 | 0.27s | 58MB |

## cbm 節點 label 分布
```
Function|535
Field|494
Macro|154
Class|121
Variable|113
Enum|27
Module|9
File|9
Folder|4
Project|1
Branch|1
```
## codegraph 節點 kind 分布
```
function|542
enum_member|124
import|99
struct|79
type_alias|37
enum|19
file|12
variable|7
constant|4
```
## 函式指標合成邊（codegraph 專有）
- codegraph fn-pointer-dispatch 合成邊: **76**
- cbm 對應合成: 無（cbm 不合成函式指標分派邊）
## 巨集節點
- cbm Macro 節點: 154
- codegraph macro 節點: 0 (codegraph 不抽巨集)

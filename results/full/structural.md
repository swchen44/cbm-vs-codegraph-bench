# 結構指標 — full
## 規模
| 工具 | nodes | edges | 索引耗時 | RAM峰值 |
|---|---|---|---|---|
| cbm | 24848 | 74219 | 4.17s | 499MB |
| codegraph | 18850 | 67712 | 14.02s | 390MB |

## cbm 節點 label 分布
```
Function|9125
Field|6241
Macro|3395
Variable|2710
Class|1775
File|509
Module|508
Enum|336
Method|201
Folder|33
Route|13
Project|1
Branch|1
```
## codegraph 節點 kind 分布
```
function|9351
import|3525
enum_member|3244
struct|706
file|651
enum|408
variable|343
constant|286
method|201
type_alias|104
class|31
```
## 函式指標合成邊（codegraph 專有）
- codegraph fn-pointer-dispatch 合成邊: **404**
- cbm 對應合成: 無（cbm 不合成函式指標分派邊）
## 巨集節點
- cbm Macro 節點: 3395
- codegraph macro 節點: 0 (codegraph 不抽巨集)

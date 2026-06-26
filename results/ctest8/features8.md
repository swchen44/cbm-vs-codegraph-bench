# 8 項 C 語法特性受控測試

受測：`repos/ctest8`（手寫 10 檔，每項特性可控 ground truth）。引擎：cbm、codegraph（tree-sitter）、clangd+compile_commands.json（= Serena/mcp-cpp 引擎）。

## 結果總表

| # | 特性 | Ground Truth | cbm | codegraph | clangd+ccjson |
|---|------|--------------|-----|-----------|---------------|
| F1 | 難解 declarator（`int (*get_op(int))(int,int)`、K&R、static、inline） | get_op 有節點；caller 函式級 | 節點✅、caller **檔案級** | **漏 get_op 節點**、caller 函式級✅ | ✅ 全函式級 |
| F2 | typedef 鏈間接呼叫（`alias_t h=t_add; h()`） | via_typedef→t_add | ❌ | ❌ 漏 | **✅ via_typedef** |
| F3 | 巨集生成函式（`DEFINE_WRAPPER(foo)`、X-macro） | foo_wrapper/cmd_alpha 等節點 + 呼叫 | ❌ 無節點 | ❌ 無節點 | **✅** foo/bar_wrapper 都在 |
| F4 | 巨集體內藏呼叫（`#define ... t_mul(...)`） | f4_caller→t_mul | ⚠️ 檔案級抓到 | ❌ 漏 | ✅ f4_caller 函式級 |
| F5 | 跨檔 static 同名（兩檔各 `static helper`） | 2 個獨立節點、各自檔內 caller | 2節點✅、caller 檔案級 | 2節點✅、caller 函式級✅ | ✅ 2節點 + 正確 scope |
| F6 | ops 分派完整性（`.op_a=t_add,.op_b=t_mul; v->op_a()`） | f6_dispatch→t_add & t_mul | ❌ | **✅ 合成器**（f6_dispatch→兩者） | ⚠️ 歸給靜態 init（VT），**不猜 runtime 指標** |
| F7 | `_Generic`（int→g_int, double→g_dbl） | f7_caller 依型別命中 | ❌ | ❌ | **✅ 依型別正確** |
| F8 | forward decl 去重（多 include 同原型 + 唯一定義） | f8_target 1 節點、caller→定義 | 1節點✅、caller 檔案級(歸 header) | 1節點✅、caller 函式級✅ | ✅ 1節點 + 函式級 |

## 計分（粗略）
- **clangd+ccjson**：F1-F5、F7、F8 全 ✅（7/8），F6 屬「精確不猜 runtime」→ **難特性全面領先**。
- **codegraph**：F5、F6、F8 ✅，F1 caller✅但漏節點；F2/F3/F4/F7 ❌ → 強在直接呼叫與**函式指標合成**，弱在巨集/typedef/_Generic。
- **cbm**：F1/F5/F8 節點✅、F4 巨集呼叫檔案級抓到；caller 普遍**檔案級**；F2/F3/F6/F7 ❌。

## 三個關鍵發現
1. **clangd 在「需要 preprocess 或型別解析」的特性上壓倒性勝**：F2 typedef 鏈、F3 巨集生成函式、F4 巨集呼叫、F7 `_Generic` —— 因它真的跑編譯器前端。tree-sitter 兩派在這些上普遍失手。
2. **codegraph 的函式指標合成器獨家拿下 F6**：`f6_dispatch→t_add/t_mul` 連 **clangd 都不給**（clangd 精確、不猜 runtime 指標，只把 `.op_a=t_add` 歸給靜態 init 點）。這是「過度近似」反而有用的少數場景。
3. **共同盲區**：F3 巨集**生成的函式定義** —— cbm 與 codegraph **都不建節點**（cbm 的 simplecpp 只在抓 CALLS 時展開，定義仍走原始碼 parse）。要這類符號只能靠 clangd。

> 對應 sub-agent 查證的 cbm 檔案級根因：C 的 tree-sitter `function_definition` 無 `name` 欄位 → `helpers.c:741` 抽不到名字 → fallback module_qn（`cbm.c:718-724` 自承）。F1/F4/F8 的「檔案級 caller」正是此 bug 的體現。

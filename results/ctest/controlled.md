# 受控實驗：#ifdef、巨集藏呼叫、建構（三引擎）

受測：`repos/ctest`（手寫小專案，ground truth 完全可控）。三引擎：cbm、codegraph（tree-sitter）、clangd（+ compile_commands.json，= Serena/mcp-cpp 對 C 的引擎）。

## 測試碼重點
```c
#define WRAP_CALL(x) real_handler(x)        // 巨集藏住對內部函式的呼叫
#ifdef FEATURE_X
int feature_func(void){ return real_handler(1); }   // 只在 -DFEATURE_X 時有效
#else
int fallback_func(void){ return 0; }                 // 只在無 -DFEATURE_X 時有效
#endif
int caller(int x){ return WRAP_CALL(x); }   // 經巨集呼叫 real_handler
```

## 結果

| 維度 | cbm | codegraph | clangd + compile_commands.json |
|------|-----|-----------|-------------------------------|
| **#ifdef 精準度**（-DFEATURE_X 時應只有 feature_func） | ❌ 兩分支都收 | ❌ 兩分支都收 | ✅ **只 feature_func**；改成無 -D 則只 fallback_func（隨旗標翻轉） |
| **巨集藏呼叫**（caller→real_handler） | ⚠️ **有抓到**（simplecpp 展開）但**檔案級** | ❌ **漏掉**（不展開巨集） | ✅ **抓到且函式級** |
| struct（`ops`） | Class | struct | ✅ |
| enum（`color`） | Enum | enum | ✅ |
| inline（`inline_helper`） | Function | function | ✅ |
| macro 節點（`WRAP_CALL`） | ✅ Macro 節點 | ❌ 無 | 解析但不建「節點」 |

## 重點

1. **#ifdef 過度涵蓋：只有 clangd（+compile_commands.json）解得對**。它隨 `-DFEATURE_X` 翻轉（有→feature_func、無→fallback_func）；codegraph/cbm 永遠兩分支都收（tree-sitter 不評估條件編譯）。**這就是 compile_commands.json 的第二個決定性價值**（第一個是函式級跨檔呼叫圖）。
2. **巨集藏呼叫：終於分出勝負**。先前 redis 的 `os_memcpy→memcpy` 因 memcpy 是外部 libc 無節點，測不出差異；本受控用**內部** real_handler：
   - **cbm 的 simplecpp 真的有用**——抓到了 codegraph 漏掉的巨集呼叫（但仍掛檔案級）。
   - **codegraph 漏掉**（不展開巨集）。
   - **clangd 最完整**：抓到 + 函式級。
3. **基本建構（struct/enum/inline）三者都行**；cbm 獨有 Macro 節點。

## 對 Serena 的意義
Serena 的 solidlsp 框架含 `clangd_language_server.py` → **Serena 對 C 用 clangd**。故 Serena 的 `find_referencing_symbols`/`find_symbol` 結果 == 本表 clangd 欄（前提：專案有 compile_commands.json）。

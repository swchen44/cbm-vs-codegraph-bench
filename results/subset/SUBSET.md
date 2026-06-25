# wpa_supplicant 子集與 Ground Truth

## 子集檔案（12 個，~21.7K 行）
從 `digsrc/wpa_supplicant` 複製，保留相對路徑讓跨檔解析有機會運作：

| 檔案 | 角色 | 代表的難題 |
|------|------|-----------|
| `src/drivers/driver.h` | `struct wpa_driver_ops`（128 函式指標欄位）定義 | 函式指標分派表（介面定義端） |
| `src/drivers/driver_wext.c` | `wpa_driver_wext_ops = {.scan2 = wpa_driver_wext_scan, ...}` 註冊 | 分派表（註冊端 1） |
| `src/drivers/driver_nl80211.c` | `wpa_driver_nl80211_ops = {.scan2 = driver_nl80211_scan2, ...}` 註冊 | 分派表（註冊端 2）＋ 大量 `#ifdef CONFIG_*` |
| `wpa_supplicant/driver_i.h` | `wpa_drv_scan()` → `wpa_s->driver->scan2(...)` 分派 | 分派點（間接呼叫） |
| `wpa_supplicant/scan.c` | 呼叫 `wpa_drv_scan` 的上層 | 呼叫鏈起點 |
| `src/utils/eloop.c/.h` | `eloop_register_timeout(cb,...)` 事件迴圈 | callback 指標傳遞（延遲呼叫） |
| `src/utils/common.h`、`os.h` | `#define os_memcpy(d,s,n) memcpy(...)` 等巨集 | 巨集藏呼叫 |

## Ground Truth（人工讀碼確認）

### 函式指標分派（Q1/Q2/Q3）
- **介面欄位**：`struct wpa_driver_ops.scan2`（`driver.h`）。
- **分派點**：`wpa_drv_scan()`（`driver_i.h:90`，`static inline`）→ `wpa_s->driver->scan2(wpa_s->drv_priv, params)`。
- **註冊的 handler（正確答案）**：
  - `wpa_driver_wext_scan`（`driver_wext.c:2497` `.scan2 =`）
  - `driver_nl80211_scan2`（`driver_nl80211.c:8709` `.scan2 =`）
- 正確的 dispatcher→handler 邊：`wpa_drv_scan → wpa_driver_wext_scan`、`wpa_drv_scan → driver_nl80211_scan2`。

### Callback 指標傳遞（Q4）
- `wpa_driver_wext_scan_timeout` 由 `eloop_register_timeout(timeout, 0, wpa_driver_wext_scan_timeout, drv, ...)`（`driver_wext.c:1140`）註冊。
- **真正的呼叫點**：`eloop_run()`（`eloop.c`）在逾時時間接呼叫，靜態分析看不到。正確答案＝「無直接靜態呼叫者，只有註冊點」。

### 巨集藏呼叫（Q5）
- `os_memcpy` 是巨集：`#define os_memcpy(d, s, n) memcpy((d), (s), (n))`（`os.h:503`）。
- `driver_wext.c` 呼叫 `os_memcpy` 35 次。展開後實際呼叫 `memcpy`。
- 注意：`memcpy`/`malloc` 是 libc 外部符號，子集無定義 → 無 Function 節點可連。此題改測「工具是否把 `os_memcpy` 當 Macro 節點 / 是否展開」。

### #ifdef 過度涵蓋（Q6）
- `nl80211_mgmt_subscribe_mesh` 等函式位於 `#ifdef CONFIG_*` 區塊內。一般 build 未開該 CONFIG 時，真實 build 無此函式；測工具是否仍收錄（過度涵蓋）。
- 整包另用 `p2p_init`（`#ifdef CONFIG_P2P`）。

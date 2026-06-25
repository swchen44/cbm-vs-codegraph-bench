# 考題結果 — full
## Q1 誰呼叫 wpa_driver_wext_scan?（fnptr 分派正向）
- codegraph: hostapd_driver_scan, wpa_drv_scan, wpa_priv_cmd_scan, driver_wext.c
- cbm(trace_path): (空)
## Q2 wpa_drv_scan 分派到?（fnptr 分派反向，GT: wext_scan/nl80211_scan2/privsep_scan）
- codegraph: driver_nl80211_scan2, wpa_driver_privsep_scan, wpa_driver_wext_scan
- cbm: (空)
## Q3 .scan2 欄位註冊了哪些函式?（候選列舉）
- codegraph(合成邊): driver_nl80211_scan2,wpa_driver_privsep_scan,wpa_driver_wext_scan
## Q4 wpa_driver_wext_scan_timeout 誰呼叫?（callback 盲區，GT: 僅註冊點）
- codegraph: wpa_driver_wext_event_wireless, wpa_driver_wext_deinit, wpa_driver_wext_scan
- cbm: (空)
## Q5 巨集處理（os_memcpy）
- cbm Macro 節點 os_memcpy: 1
- codegraph os_memcpy 節點: 2
## Q6 #ifdef 過度涵蓋（nl80211_mgmt_subscribe_mesh 在 CONFIG 區塊內）
- cbm 收錄: 1
- codegraph 收錄: 1

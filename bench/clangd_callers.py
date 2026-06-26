#!/usr/bin/env python3
"""驅動 clangd (LSP over stdio) 取某函式的「函式級 callers」(callHierarchy/incomingCalls)。
用法: clangd_callers.py <project_root> <file_abs> <symbol> [clangd_bin]
- project_root 有 compile_commands.json 時 clangd 會用它建 background index (跨檔正確解析)。
- 沒有時 clangd 退化為猜測 flags / 僅開啟檔。
輸出: JSON {"symbol":..., "callers":[函式名...], "indexed_files":N}
"""
import sys, os, json, subprocess, threading, time, re

root, fpath, sym = sys.argv[1], sys.argv[2], sys.argv[3]
clangd = sys.argv[4] if len(sys.argv) > 4 else "clangd"

# 找 symbol 定義的 line/char (0-based)
src = open(fpath, encoding="utf-8", errors="replace").read()
lines = src.split("\n")
pos = None
defre = re.compile(r"\b" + re.escape(sym) + r"\s*\(")
for i, ln in enumerate(lines):
    # 取「定義行」: 行首非空白、含型別、含 sym(   (排除呼叫)
    if defre.search(ln) and not ln.lstrip().startswith(("if", "for", "while", "return", "//", "*")):
        m = re.search(r"\b" + re.escape(sym) + r"\b", ln)
        if m and (ln[0] not in " \t" or "(" in ln):
            pos = (i, m.start()); break
if pos is None:
    for i, ln in enumerate(lines):
        m = re.search(r"\b" + re.escape(sym) + r"\b", ln)
        if m: pos = (i, m.start()); break
if pos is None:
    print(json.dumps({"symbol": sym, "error": "symbol not found"})); sys.exit(0)

p = subprocess.Popen([clangd, "--background-index", "--log=error", f"--compile-commands-dir={root}"],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
_id = 0
def send(method, params, notify=False):
    global _id
    msg = {"jsonrpc": "2.0", "method": method, "params": params}
    if not notify:
        _id += 1; msg["id"] = _id
    data = json.dumps(msg).encode()
    p.stdin.write(f"Content-Length: {len(data)}\r\n\r\n".encode() + data); p.stdin.flush()
    return _id if not notify else None

resp = {}; index_files = [0]
def reader():
    buf = b""
    while True:
        chunk = p.stdout.read(1)
        if not chunk: break
        buf += chunk
        if buf.endswith(b"\r\n\r\n"):
            n = int(re.search(rb"Content-Length: (\d+)", buf).group(1))
            body = p.stdout.read(n); buf = b""
            try: m = json.loads(body)
            except: continue
            if "id" in m and "result" in m: resp[m["id"]] = m["result"]
            if m.get("method") == "$/progress":
                v = m.get("params", {}).get("value", {})
                if "message" in v and "/" in str(v.get("message", "")):
                    try: index_files[0] = int(str(v["message"]).split("/")[1])
                    except: pass
threading.Thread(target=reader, daemon=True).start()

def wait(rid, timeout=20):
    t = time.time()
    while rid not in resp and time.time() - t < timeout: time.sleep(0.05)
    return resp.get(rid)

uri = "file://" + fpath
rid = send("initialize", {"processId": os.getpid(), "rootUri": "file://" + root,
    "capabilities": {"textDocument": {"callHierarchy": {"dynamicRegistration": False}}}})
wait(rid); send("initialized", {}, notify=True)
send("textDocument/didOpen", {"textDocument": {"uri": uri, "languageId": "c", "version": 1, "text": src}}, notify=True)
time.sleep(25)  # 等 background index (有 compile_commands.json 才會跨檔索引)

rid = send("textDocument/prepareCallHierarchy", {"textDocument": {"uri": uri},
    "position": {"line": pos[0], "character": pos[1]}})
items = wait(rid, 30) or []
callers = []
if items:
    rid = send("callHierarchy/incomingCalls", {"item": items[0]})
    inc = wait(rid, 40) or []
    callers = sorted(set(c["from"]["name"] for c in inc))
print(json.dumps({"symbol": sym, "callers": callers, "n_callers": len(callers),
                  "indexed_files": index_files[0], "has_ccjson": os.path.exists(os.path.join(root, "compile_commands.json"))}))
try: p.terminate()
except: pass

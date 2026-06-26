#!/usr/bin/env python3
"""最小 MCP stdio client 驅動 Serena：initialize → tools/list → find_symbol → find_referencing_symbols。
用法: serena_mcp.py <project_path> <symbol>
"""
import sys, os, json, subprocess, threading, time, re

proj, sym = sys.argv[1], sys.argv[2]
cmd = ["uvx", "--from", "git+https://github.com/oraios/serena", "serena",
       "start-mcp-server", "--project", proj, "--transport", "stdio", "--context", "agent"]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
_id = [0]; resp = {}; notifs = []

def send(method, params, notify=False):
    msg = {"jsonrpc": "2.0", "method": method, "params": params}
    if not notify:
        _id[0] += 1; msg["id"] = _id[0]
    d = json.dumps(msg).encode()
    p.stdin.write(f"Content-Length: {len(d)}\r\n\r\n".encode() + d); p.stdin.flush()
    return _id[0] if not notify else None

def reader():
    buf = b""
    while True:
        c = p.stdout.read(1)
        if not c: break
        buf += c
        if buf.endswith(b"\r\n\r\n"):
            m = re.search(rb"Content-Length: (\d+)", buf)
            if not m: buf = b""; continue
            n = int(m.group(1)); body = p.stdout.read(n); buf = b""
            try: msg = json.loads(body)
            except: continue
            if "id" in msg: resp[msg["id"]] = msg
threading.Thread(target=reader, daemon=True).start()

def wait(rid, t=180):
    s = time.time()
    while rid not in resp and time.time() - s < t: time.sleep(0.1)
    return resp.get(rid)

rid = send("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
    "clientInfo": {"name": "bench", "version": "1"}})
init = wait(rid, 120)
print("initialize:", "ok" if init else "TIMEOUT")
send("notifications/initialized", {}, notify=True)
time.sleep(2)

rid = send("tools/list", {})
tl = wait(rid, 60)
tools = [t["name"] for t in (tl.get("result", {}).get("tools", []) if tl else [])]
print("tools(%d):" % len(tools), [t for t in tools if "symbol" in t or "refer" in t or "find" in t][:8])

# find_symbol
rid = send("tools/call", {"name": "find_symbol", "arguments": {"name_path": sym, "relative_path": "."}})
r = wait(rid, 120)
def text(r):
    if not r or "result" not in r: return "(no result/err: %s)" % (r.get("error") if r else "timeout")
    c = r["result"].get("content", [])
    return " ".join(x.get("text", "") for x in c)[:600]
print("find_symbol(%s):" % sym, text(r))

# find_referencing_symbols
rid = send("tools/call", {"name": "find_referencing_symbols",
    "arguments": {"name_path": sym, "relative_path": "."}})
r = wait(rid, 180)
print("find_referencing_symbols(%s):" % sym, text(r))

try: p.terminate()
except: pass

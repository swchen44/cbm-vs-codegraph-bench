#!/usr/bin/env bash
# setup.sh — 安裝兩個工具與 ground-truth 工具，clone 受測 repo。
# 已驗證環境：macOS, Node v26（codegraph 需用 bundled installer 繞過 Node25+ 限制）。
set -uo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT"/{repos,results/raw}

log(){ echo "[setup] $*"; }

# 1) clone 受測 repo 與工具原始碼
cd "$ROOT/repos"
[ -d wpa_supplicant ] || git clone --depth=1 https://github.com/digsrc/wpa_supplicant wpa_supplicant
[ -d cbm-fork ]       || git clone --depth=1 https://github.com/win4r/codebase-memory-mcp-pro cbm-fork
# 上游可選（build 用 make -f Makefile.cbm，本 bench 以 fork 為主）：
# [ -d cbm-upstream ] || git clone --depth=1 https://github.com/DeusData/codebase-memory-mcp cbm-upstream

# 2) codegraph：用官方 bundled installer（自帶 Node runtime，繞過系統 Node 版本限制）
if ! command -v codegraph >/dev/null 2>&1; then
  log "安裝 codegraph (bundled)..."
  curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"
codegraph version || { echo "codegraph 安裝失敗"; exit 1; }

# 3) cbm fork：自 build（Pure C，~3 分鐘首編 158 grammar）
if [ ! -x "$ROOT/repos/cbm-fork/build/c/codebase-memory-mcp" ]; then
  log "build cbm fork..."
  ( cd "$ROOT/repos/cbm-fork" && ./scripts/build.sh ) || {
    log "build 失敗，嘗試 brew install libgit2 pkg-config 後重試"
    brew install libgit2 pkg-config
    ( cd "$ROOT/repos/cbm-fork" && ./scripts/build.sh )
  }
fi

# 4) ground-truth 工具
for t in cscope cflow; do command -v $t >/dev/null 2>&1 || brew install $t; done
command -v ctags >/dev/null 2>&1 || brew install ctags

log "完成。codegraph=$(command -v codegraph)  cbm=$ROOT/repos/cbm-fork/build/c/codebase-memory-mcp"

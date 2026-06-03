#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xi-han.top Proxy Worker — 一键部署脚本
# 运行前确保已安装 Node.js 和 npm。
# 设置环境变量 CLOUDFLARE_API_TOKEN 或在下面填入。
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------- 1. 检查 Cloudflare API Token ----------
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  if [ -f "${SCRIPT_DIR}/.token" ]; then
    export CLOUDFLARE_API_TOKEN="$(cat "${SCRIPT_DIR}/.token" | tr -d '[:space:]')"
  else
    echo "❌ 需要设置 CLOUDFLARE_API_TOKEN"
    echo ""
    echo "   方式一：export CLOUDFLARE_API_TOKEN='你的token'"
    echo "   方式二：将 token 写入 ${SCRIPT_DIR}/.token"
    echo ""
    exit 1
  fi
fi

# ---------- 2. 检查 wrangler ----------
if ! command -v npx &>/dev/null; then
  echo "❌ 未找到 npx，请安装 Node.js (npm)"
  exit 1
fi

# ---------- 3. 部署 ----------
echo "🚀 部署 xi-han-proxy Worker..."
cd "$SCRIPT_DIR"

DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1)
echo "$DEPLOY_OUTPUT"

# ---------- 4. 验证 ----------
if echo "$DEPLOY_OUTPUT" | grep -q "Uploaded\|Deployed"; then
  echo ""
  echo "✅ 部署成功！"
  echo "   Worker 地址: https://xi-han-proxy.xi-han.workers.dev"
  echo ""
  echo "   可用路由:"
  echo "     https://xi-han.top/github.com/*"
  echo "     https://xi-han.top/raw.githubusercontent.com/*"
  echo "     https://xi-han.top/gist.github.com/*"
  echo "     https://xi-han.top/api.github.com/*"
  echo "     https://xi-han.top/xray"
  echo "     https://xi-han.top/xray.html"
else
  echo "❌ 部署失败，请检查上面的错误信息"
  exit 1
fi

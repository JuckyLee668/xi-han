#!/bin/bash
# v2rayA + Xray-core 一键安装脚本
# 支持从 xi-han.top 镜像或 GitHub 直连下载
# 适用于 Debian/Ubuntu 系 (x86_64 / arm64)
#
# 用法:
#   chmod +x install-v2raya.sh && sudo ./install-v2raya.sh
#   MIRROR_BASE="" sudo ./install-v2raya.sh   # 强制走 GitHub
#
# 环境变量:
#   MIRROR_BASE    镜像前缀 (默认 https://xi-han.top/github.com)
#   V2RAYA_VER     v2rayA 版本 (默认自动获取最新)
#   XRAY_VER       Xray-core 版本 (默认自动获取最新)

set -euo pipefail

# ── 颜色 ──
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC}  $1"; }

# ── 配置 ──
MIRROR_BASE="${MIRROR_BASE:-https://xi-han.top/github.com}"  # 留空 = 只用 GitHub
GITHUB_BASE="https://github.com"

TMPDIR=$(mktemp -d /tmp/v2raya-install-XXXXXX)
trap 'rm -rf "$TMPDIR"' EXIT

# ── 检测架构 ──
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)  echo "x64" ;;
        aarch64|arm64)  echo "arm64" ;;
        armv7l|armv7)   echo "armv7" ;;
        *) err "不支持的架构: $arch"; exit 1 ;;
    esac
}

# ── 检测发行版 ──
detect_os() {
    if [ ! -f /etc/os-release ]; then
        err "仅支持 Debian/Ubuntu 系系统"
        exit 1
    fi
    . /etc/os-release
    case "$ID" in
        debian|ubuntu|kali) echo "$ID" ;;
        *) err "不支持的系统: $ID (仅 Debian/Ubuntu)"; exit 1 ;;
    esac
}

# ── 获取最新版本号 ──
get_latest_release() {
    local repo="$1"        # e.g. "v2rayA/v2rayA"
    local api_url="$2"     # "releases/latest" or "releases"
    local tag_filter="$3"  # grep pattern for tag_name

    local url="${GITHUB_BASE}/${repo}/${api_url}"
    local tag

    # 尝试从镜像获取 API 数据
    if [ -n "$MIRROR_BASE" ]; then
        tag=$(curl -sfL --connect-timeout 10 \
            "${MIRROR_BASE}/${repo}/${api_url}" 2>/dev/null \
            | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4) \
        || tag=""
    fi

    # 失败则直连 GitHub
    if [ -z "$tag" ]; then
        tag=$(curl -sfL --connect-timeout 15 \
            "https://api.github.com/repos/${repo}/${api_url}" \
            | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4) \
        || { err "无法获取 ${repo} 最新版本"; return 1; }
    fi

    echo "$tag"
}

# ── 下载文件 (镜像优先 → GitHub 直连兜底) ──
download() {
    local url_path="$1"   # e.g. /XTLS/Xray-core/releases/download/...
    local output="$2"

    # 镜像优先
    if [ -n "$MIRROR_BASE" ]; then
        if curl -fsSL --connect-timeout 15 -o "$output" \
            "${MIRROR_BASE}${url_path}" 2>/dev/null; then
            return 0
        fi
        info "镜像下载失败, 切换 GitHub 直连..."
    fi

    curl -fsSL --connect-timeout 20 -o "$output" \
        "${GITHUB_BASE}${url_path}" || {
        err "下载失败: ${GITHUB_BASE}${url_path}"
        return 1
    }
}

# ═══════════════════════════════════════════════
#  主流程
# ═══════════════════════════════════════════════

main() {
    echo -e "\n${CYAN}━━━━━━━ v2rayA + Xray-core 一键安装 ━━━━━━━${NC}\n"

    # ── 1. 权限检查 ──
    if [ "$(id -u)" -ne 0 ]; then
        err "请以 root 运行: sudo $0"
        exit 1
    fi

    # ── 2. 检测系统 ──
    ARCH=$(detect_arch)
    OS=$(detect_os)
    info "系统: ${OS} | 架构: ${ARCH}"

    # ── 3. 安装基础依赖 ──
    info "安装系统依赖..."
    apt-get update -qq
    apt-get install -y -qq curl wget unzip gnupg ca-certificates systemd >/dev/null 2>&1
    ok "系统依赖已安装"

    # ── 4. 获取最新版本 ──
    info "获取最新版本号..."
    XRAY_VER="${XRAY_VER:-$(get_latest_release XTLS/Xray-core releases/latest latest)}"
    V2RAYA_VER="${V2RAYA_VER:-$(get_latest_release v2rayA/v2rayA releases/latest latest)}"
    ok "Xray-core: ${XRAY_VER}  |  v2rayA: ${V2RAYA_VER}"

    # 去掉版本号前的 'v' 用于文件名
    XRAY_VER_NUM="${XRAY_VER#v}"
    V2RAYA_VER_NUM="${V2RAYA_VER#v}"

    # ── 5. 下载 Xray-core ──
    XRAY_FILE="Xray-linux-64.zip"
    if [ "$ARCH" = "arm64" ]; then
        XRAY_FILE="Xray-linux-arm64-v8a.zip"
    elif [ "$ARCH" = "armv7" ]; then
        XRAY_FILE="Xray-linux-arm32-v7a.zip"
    fi

    info "下载 Xray-core ${XRAY_VER}..."
    download "/XTLS/Xray-core/releases/download/${XRAY_VER}/${XRAY_FILE}" \
        "${TMPDIR}/xray.zip"
    ok "Xray-core 下载完成 (${XRAY_FILE})"

    # ── 6. 安装 Xray-core ──
    info "安装 Xray-core..."
    mkdir -p /usr/local/share/xray /usr/local/bin
    unzip -qo "${TMPDIR}/xray.zip" -d "${TMPDIR}/xray-extract/"
    # 找 xray 主程序 (可能是 xray 或 Xray)
    if [ -f "${TMPDIR}/xray-extract/xray" ]; then
        cp "${TMPDIR}/xray-extract/xray" /usr/local/bin/xray
    elif [ -f "${TMPDIR}/xray-extract/Xray" ]; then
        cp "${TMPDIR}/xray-extract/Xray" /usr/local/bin/xray
    else
        err "Xray-core 压缩包中未找到 xray 二进制文件"
        ls -la "${TMPDIR}/xray-extract/"
        exit 1
    fi
    chmod 755 /usr/local/bin/xray
    # 复制资源文件 (geoip.dat, geosite.dat)
    cp "${TMPDIR}/xray-extract/"*.dat /usr/local/share/xray/ 2>/dev/null || true
    ok "Xray-core 已安装 ($(/usr/local/bin/xray --version 2>&1 | head -1))"

    # ── 7. 下载并安装 v2rayA (deb) ──
    V2RAYA_DEB="installer_${OS}_${ARCH}_${V2RAYA_VER_NUM}.deb"
    info "下载 v2rayA ${V2RAYA_VER} (${V2RAYA_DEB})..."
    download "/v2rayA/v2rayA/releases/download/${V2RAYA_VER}/${V2RAYA_DEB}" \
        "${TMPDIR}/v2raya.deb"

    info "安装 v2rayA..."
    dpkg -i "${TMPDIR}/v2raya.deb" 2>/dev/null || {
        # 处理依赖缺失
        apt-get install -f -y -qq >/dev/null 2>&1
        dpkg -i "${TMPDIR}/v2raya.deb" 2>/dev/null
    }
    ok "v2rayA 已安装 ($(v2raya --version 2>&1 | head -1))"

    # ── 8. 配置 Xray-core 路径 (让 v2rayA 能找到) ──
    mkdir -p /etc/v2raya
    # v2rayA 默认会找 /usr/local/bin/xray, 确认一下
    if [ ! -f /etc/v2raya/xray ]; then
        # 如果 v2rayA 创建了配置目录但没写 xray 路径, 保持默认行为
        true
    fi

    # ── 9. 清理 ──
    rm -rf "$TMPDIR"
    trap '' EXIT

    # ── 10. 启动服务 ──
    info "启动 v2rayA 服务..."
    systemctl enable v2raya --now 2>/dev/null || systemctl daemon-reload && systemctl enable v2raya --now

    # 等待启动
    sleep 2
    if systemctl is-active --quiet v2raya; then
        ok "v2rayA 服务运行中"
    else
        warn "v2rayA 服务未启动, 请检查: journalctl -u v2raya -n 30 --no-pager"
    fi

    # ── 11. 完成 ──
    LOCAL_IP=$(ip -4 addr show | grep -oP 'inet \K[0-9.]+' | grep -v '127.0.0.1' | head -1)
    echo ""
    echo -e "${GREEN}──────────────────────────────────────────────${NC}"
    echo -e " ${GREEN}✔ 安装完成！${NC}"
    echo ""
    echo -e "  ${CYAN}v2rayA 面板:${NC} http://${LOCAL_IP}:2017"
    echo -e "  ${CYAN}Xray-core:${NC}  $(/usr/local/bin/xray --version 2>&1 | head -1)"
    echo -e "  ${CYAN}v2rayA:${NC}    $(v2raya --version 2>&1 | head -1)"
    echo ""
    echo -e "  ${YELLOW}首次访问面板, 请先注册管理员账号${NC}"
    echo ""
    echo -e "  ${CYAN}常用命令:${NC}"
    echo -e "    systemctl status v2raya     查看服务状态"
    echo -e "    journalctl -u v2raya -f     实时查看日志"
    echo -e "    v2raya --help                 查看帮助"
    echo -e "${GREEN}──────────────────────────────────────────────${NC}"
}

main "$@"

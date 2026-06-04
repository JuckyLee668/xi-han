# Worker 代理部署文档

为 `xi-han.top` 提供 GitHub 全套代理访问（页面、API、资源文件、下载），国内可直接访问。

## 目录结构

```
proxy/worker/
├── src/index.js       # Worker 源码
├── wrangler.toml      # Cloudflare Workers 配置
├── deploy.sh          # 一键部署脚本
└── README.md          # 本文件
```

## 支持的域名

使用 `https://xi-han.top/<domain>/<path>` 格式，自动代理到 `https://<domain>/<path>`。

| 域名 | 用途 |
|------|------|
| `github.com` | GitHub 页面、Releases、下载 |
| `raw.githubusercontent.com` | raw 文件 |
| `gist.github.com` | Gist |
| `api.github.com` | API |
| `github.githubassets.com` | CSS/JS/字体（页面渲染必需） |
| `avatars.githubusercontent.com` | 头像 |
| `user-images.githubusercontent.com` | 用户上传的图片 |
| `objects.githubusercontent.com` | Release 二进制文件下载 |
| `camo.githubusercontent.com` | 缓存图片 |
| `github-cloud.s3.amazonaws.com` | GitHub 云存储 |

## 特殊功能

- **HTML 链接自动重写** — 页面中的所有 `github.com` / `githubusercontent.com` 链接自动替换为代理链接，点击即走代理
- **相对路径导航** — 从代理页面点击的相对路径（如 `/login`、`/session`）自动转发到 GitHub
- **Xray 页面** — `/xray` 和 `/xray.html` 映射到 `/html/xray.html`

## 部署

### 前置条件
- Node.js >= 18（含 npm）
- Cloudflare API Token（[创建地址](https://dash.cloudflare.com/profile/api-tokens)）
- 域名 `xi-han.top` 已在 Cloudflare 接入（DNS 开启代理）

### 一键部署

```bash
cd proxy/worker
export CLOUDFLARE_API_TOKEN='你的token'
bash deploy.sh
```

或者在 `proxy/worker/.token` 文件中写入 token，之后可直接运行：

```bash
cd proxy/worker && bash deploy.sh
```

### 手动部署

```bash
cd proxy/worker
npx wrangler deploy
```

## Cloudflare 配置

- DNS 记录指向 GitHub Pages IP（`185.199.108.153` 等）
- 开启代理（橙色云朵）
- SSL/TLS 设为 Full 或 Flexible
- Worker 路由 `xi-han.top/*` 覆盖所有请求，Worker 自动判断代理或透传

## 测试

```bash
# 测试 GitHub 页面
curl -sI https://xi-han.top/github.com/2dust/v2rayN

# 测试 Release 页面（含 assets）
curl -s https://xi-han.top/github.com/2dust/v2rayN/releases | head -50

# 测试 API
curl -s https://xi-han.top/api.github.com/repos/2dust/v2rayN/releases/latest

# 测试 raw 文件
curl -s https://xi-han.top/raw.githubusercontent.com/JuckyLee668/xi-han/main/README.md

# 测试 xray 页面
curl -sI https://xi-han.top/xray
```

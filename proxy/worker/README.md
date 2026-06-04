# Worker 代理 — GitHub 只读代理

为 `xi-han.top` 提供 GitHub 代理访问（页面浏览、Release 下载、API 调用），国内可直接访问。

> ⚠️ **只读代理** — 不支持登录、Issues、PR 等需要 GitHub Cookie 的操作。
> GitHub 的 session cookie 绑定 `domain=.github.com`，浏览器不会设置到 `xi-han.top`。

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
| `github.com` | 公开仓库浏览、Releases、下载 |
| `raw.githubusercontent.com` | raw 文件 |
| `gist.github.com` | 公开 Gist |
| `api.github.com` | 公开 API |
| `github.githubassets.com` | CSS/JS/字体（页面渲染必需） |
| `avatars.githubusercontent.com` | 头像 |
| `user-images.githubusercontent.com` | 用户上传的图片 |
| `objects.githubusercontent.com` | Release 二进制文件下载 |
| `camo.githubusercontent.com` | 缓存图片 |
| `github-cloud.s3.amazonaws.com` | GitHub 云存储 |

## 特殊功能

- **HTML 链接自动重写** — 页面中所有 `github.com` / `githubusercontent.com` / `githubassets.com` 链接自动替换为代理链接
- **相对路径导航** — 从代理页面点击的相对路径（如 `/login`、`/session`）自动转发到 GitHub
- **CSP 自动修补** — 自动修改 GitHub 的 Content-Security-Policy，允许从 `xi-han.top` 加载资源（CSS、JS、字体等）
- **Xray 页面** — `/xray` 和 `/xray.html` 映射到 `/html/xray.html`

## 限制

| 功能 | 支持 |
|------|------|
| 浏览公开仓库、Releases | ✅ |
| 下载 Release 文件 | ✅ |
| 查看 raw 文件 | ✅ |
| 调用公开 API | ✅ |
| **登录** | ❌ Cookie 域名不匹配 |
| **Issues / PR / 评论区** | ❌ 需登录 |
| **私有仓库** | ❌ 需登录 |

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

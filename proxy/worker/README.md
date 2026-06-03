# Worker 代理部署文档

为 `xi-han.top` 提供 GitHub 代理访问，国内可直接下载、浏览 GitHub 资源。

## 目录结构

```
proxy/worker/
├── src/index.js       # Worker 源码
├── wrangler.toml      # Cloudflare Workers 配置
├── deploy.sh          # 一键部署脚本
└── README.md          # 本文件
```

## 路由

| 路径 | 作用 | 示例 |
|------|------|------|
| `/github.com/*` | 代理 GitHub 页面/下载 | `/github.com/2dust/v2rayN/releases` |
| `/raw.githubusercontent.com/*` | 代理 raw 文件 | `/raw.githubusercontent.com/user/repo/main/file` |
| `/gist.github.com/*` | 代理 Gist | `/gist.github.com/user/gistid` |
| `/api.github.com/*` | 代理 GitHub API | `/api.github.com/repos/2dust/v2rayN/releases/latest` |
| `/xray` | Xray 订阅页面 | 自动跳转到 `/html/xray.html` |
| `/xray.html` | Xray 订阅页面 | 自动跳转到 `/html/xray.html` |

## 部署

### 前置条件
- Node.js >= 18 (npm)
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

在 Cloudflare Dashboard 中，域名 `xi-han.top` 必须：
1. DNS 记录指向 GitHub Pages IP（`185.199.108.153` 等）
2. 开启代理（橙色云朵）
3. SSL/TLS 设置为 Full 或 Flexible
4. Worker 路由会自动覆盖上述路径，其余请求直通 GitHub Pages

## 测试

```bash
# 测试 GitHub 代理
curl -sI https://xi-han.top/github.com/2dust/v2rayN

# 测试 API
curl -s https://xi-han.top/api.github.com/repos/2dust/v2rayN/releases/latest

# 测试 raw 文件
curl -s https://xi-han.top/raw.githubusercontent.com/JuckyLee668/xi-han/main/README.md

# 测试 xray 页面
curl -sI https://xi-han.top/xray
```

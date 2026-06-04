// xi-han.top Proxy Worker — GitHub read-only proxy + Xray page alias
// ⚠️ 不支持登录（Cookie 绑定 github.com 域名），仅限公开访问
// Deploy: cd proxy/worker && bash deploy.sh
//
// Routes (wrangler.toml):
//   xi-han.top/github.com/*
//   xi-han.top/raw.githubusercontent.com/*
//   xi-han.top/gist.github.com/*
//   xi-han.top/api.github.com/*
//   xi-han.top/*.github.com/*       ← catch-all for *.github.com subdomains
//   xi-han.top/*.githubusercontent.com/*  ← GitHub CDN assets
//   xi-han.top/xray
//   xi-han.top/xray.html
//
// Path convention: /<domain>/<path>  e.g. /github.com/user/repo

const GITHUB_DOMAINS = new Set([
  'github.com',
  'raw.githubusercontent.com',
  'gist.github.com',
  'api.github.com',
]);

const ASSET_DOMAINS = new Set([
  'github.githubassets.com',
  'avatars.githubusercontent.com',
  'user-images.githubusercontent.com',
  'objects.githubusercontent.com',
  'camo.githubusercontent.com',
  'github-cloud.s3.amazonaws.com',
]);

const ALL_DOMAINS = new Set([...GITHUB_DOMAINS, ...ASSET_DOMAINS]);

// Match any github.com or githubusercontent.com URL in HTML
const GITHUB_URL_RE = /(href|src|action)=["']https?:\/\/((?:[^\/"']*\.)?github\.com|(?:[^\/"']*\.)?githubusercontent\.com|(?:[^\/"']*\.)?githubassets\.com|(?:[^\/"']*\.)?s3\.amazonaws\.com)([^"']*)["']/gi;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const pathname = url.pathname;
    const proxyBase = `${url.protocol}//${url.host}`;

    // Xray page aliases
    if (pathname === '/xray' || pathname === '/xray.html') {
      const xrayUrl = `${url.protocol}//${url.host}/html/xray.html`;
      return proxyFetch(request, xrayUrl, proxyBase);
    }

    // Parse: /<domain>/<path> → https://<domain>/<path>
    const firstSlash = pathname.indexOf('/', 1);
    const hostPrefix = firstSlash === -1 ? pathname.slice(1) : pathname.slice(1, firstSlash);
    const rest = firstSlash === -1 ? '' : pathname.slice(firstSlash);

    if (ALL_DOMAINS.has(hostPrefix)) {
      const upstream = `https://${hostPrefix}${rest}${url.search}`;
      return proxyFetch(request, upstream, proxyBase);
    }

    // Relative-path navigation from a proxied GitHub page (e.g. /login, /session)
    const referer = request.headers.get('Referer') || '';
    const fromGitHubProxy = referer.includes('/github.com/') || referer.includes('/github.githubassets.com/');
    if (fromGitHubProxy) {
      const upstream = `https://github.com${pathname}${url.search}`;
      return proxyFetch(request, upstream, proxyBase);
    }

    // Pass through to origin (GitHub Pages)
    return fetch(request);
  },
};

async function proxyFetch(request, upstreamUrl, proxyBase) {
  const headers = new Headers(request.headers);
  headers.delete('cf-connecting-ip');
  headers.delete('x-forwarded-for');
  headers.delete('x-real-ip');
  headers.set('Host', new URL(upstreamUrl).host);
  headers.set('Accept-Encoding', 'gzip');

  const fetchInit = { method: request.method, headers, redirect: 'follow' };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    fetchInit.body = request.body;
  }

  const response = await fetch(upstreamUrl, fetchInit);
  const responseHeaders = new Headers(response.headers);
  responseHeaders.set('Access-Control-Allow-Origin', '*');

  // GitHub's Content-Security-Policy restricts resources to github.githubassets.com
  // but we serve them via xi-han.top. Patch CSP to allow our proxy domain.
  const csp = responseHeaders.get('Content-Security-Policy');
  if (csp) {
    const proxyHost = new URL(proxyBase).host;
    const patched = csp.replace(/(\S+-src\s+)([^;]+)/gi, (match, directive, sources) => {
      return directive + proxyHost + ' ' + sources;
    });
    responseHeaders.set('Content-Security-Policy', patched);
  }

  // Strip GitHub-specific cookies (domain mismatch causes warnings)
  responseHeaders.delete('set-cookie');

  const contentType = responseHeaders.get('Content-Type') || '';
  const isText = contentType.includes('text/') ||
    contentType.includes('application/json') ||
    contentType.includes('application/javascript') ||
    contentType.includes('application/xml');

  if (isText && response.headers.get('Content-Encoding')) {
    responseHeaders.delete('Content-Encoding');
    const text = await response.text();
    if (contentType.includes('text/html')) {
      const rewritten = text.replace(GITHUB_URL_RE,
        (match, attr, host, path) => `${attr}="${proxyBase}/${host}${path}"`
      );
      return new Response(rewritten, {
        status: response.status,
        statusText: response.statusText,
        headers: responseHeaders,
      });
    }
    return new Response(text, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders,
    });
  }

  if (contentType.includes('text/html')) {
    const text = await response.text();
    const rewritten = text.replace(GITHUB_URL_RE,
      (match, attr, host, path) => `${attr}="${proxyBase}/${host}${path}"`
    );
    return new Response(rewritten, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders,
    });
  }

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: responseHeaders,
  });
}

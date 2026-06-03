// xi-han.top Proxy Worker — GitHub proxy + Xray page alias
// Deploy: cd proxy/worker && bash deploy.sh
// Routes:
//   /github.com/*           → https://github.com/*
//   /raw.githubusercontent.com/* → https://raw.githubusercontent.com/*
//   /gist.github.com/*      → https://gist.github.com/*
//   /api.github.com/*       → https://api.github.com/*
//   /xray                   → serve /html/xray.html
//   /xray.html              → serve /html/xray.html

const ROUTES = {
  '/github.com/': 'https://github.com',
  '/raw.githubusercontent.com/': 'https://raw.githubusercontent.com',
  '/gist.github.com/': 'https://gist.github.com',
  '/api.github.com/': 'https://api.github.com',
};

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

    // GitHub proxy routes
    for (const [prefix, baseUrl] of Object.entries(ROUTES)) {
      if (pathname === prefix || pathname.startsWith(prefix)) {
        const rest = pathname.slice(prefix.length - 1);
        return proxyFetch(request, `${baseUrl}${rest}${url.search}`, proxyBase);
      }
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

  const contentType = responseHeaders.get('Content-Type') || '';
  const isText = contentType.includes('text/') || contentType.includes('application/json') || contentType.includes('application/javascript') || contentType.includes('application/xml');
  if (isText && response.headers.get('Content-Encoding')) {
    responseHeaders.delete('Content-Encoding');
    const text = await response.text();
    if (contentType.includes('text/html')) {
      const rewritten = text.replace(
        /(href|src|action)=["']https?:\/\/([^\/]+\.github\.com|[^\/]+github\.com)([^"']*)["']/gi,
        (match, attr, host, path) => `${attr}="${proxyBase}/github.com/${host}${path}"`
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
    const rewritten = text.replace(
      /(href|src|action)=["']https?:\/\/([^\/]+\.github\.com|[^\/]+github\.com)([^"']*)["']/gi,
      (match, attr, host, path) => `${attr}="${proxyBase}/github.com/${host}${path}"`
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

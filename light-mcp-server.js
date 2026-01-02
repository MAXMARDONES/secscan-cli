#!/usr/bin/env node
/**
 * light-mcp-server.js
 * Super lightweight MCP-style backend in pure Node.js (no dependencies)
 * 
 * Endpoints:
 *   GET  /health          - Health check
 *   GET  /info            - Server info
 *   POST /scan            - Trigger a scan (placeholder)
 *   POST /echo            - Echo back JSON body
 *   GET  /reports         - List reports in current dir
 *   GET  /reports/:name   - Get a specific report
 * 
 * Usage:
 *   node light-mcp-server.js [port]
 *   PORT=8080 node light-mcp-server.js
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const url = require('url');

const PORT = process.env.PORT || process.argv[2] || 3000;
const REPORTS_DIR = process.env.REPORTS_DIR || process.cwd();

// Utility: parse JSON body
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end', () => {
      try {
        resolve(data ? JSON.parse(data) : {});
      } catch (e) {
        reject(e);
      }
    });
    req.on('error', reject);
  });
}

// Utility: send JSON response
function json(res, statusCode, data) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data, null, 2));
}

// Utility: send text/markdown response
function text(res, statusCode, data, contentType = 'text/plain') {
  res.writeHead(statusCode, { 'Content-Type': contentType });
  res.end(data);
}

// Route handlers
const routes = {
  'GET /health': (req, res) => {
    json(res, 200, { status: 'ok', timestamp: new Date().toISOString() });
  },

  'GET /info': (req, res) => {
    json(res, 200, {
      name: 'light-mcp-server',
      version: '1.0.0',
      node: process.version,
      platform: process.platform,
      uptime: process.uptime(),
      cwd: process.cwd(),
      reportsDir: REPORTS_DIR
    });
  },

  'POST /echo': async (req, res) => {
    try {
      const body = await parseBody(req);
      json(res, 200, { echo: body, receivedAt: new Date().toISOString() });
    } catch (e) {
      json(res, 400, { error: 'Invalid JSON', message: e.message });
    }
  },

  'GET /reports': (req, res) => {
    try {
      const files = fs.readdirSync(REPORTS_DIR)
        .filter(f => f.endsWith('.md') || f.endsWith('.log'))
        .map(f => {
          const stat = fs.statSync(path.join(REPORTS_DIR, f));
          return { name: f, size: stat.size, modified: stat.mtime };
        })
        .sort((a, b) => b.modified - a.modified);
      json(res, 200, { reports: files });
    } catch (e) {
      json(res, 500, { error: 'Failed to list reports', message: e.message });
    }
  },

  'GET /reports/:name': (req, res, params) => {
    const filePath = path.join(REPORTS_DIR, params.name);
    if (!fs.existsSync(filePath)) {
      return json(res, 404, { error: 'Report not found' });
    }
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const contentType = params.name.endsWith('.md') ? 'text/markdown' : 'text/plain';
      text(res, 200, content, contentType);
    } catch (e) {
      json(res, 500, { error: 'Failed to read report', message: e.message });
    }
  },

  'POST /scan': async (req, res) => {
    try {
      const body = await parseBody(req);
      const domains = body.domains || [];
      if (!domains.length) {
        return json(res, 400, { error: 'No domains provided', usage: { domains: ['example.com'] } });
      }

      // Check if scanner exists
      const scannerPath = path.join(__dirname, 'heavy_secscan.sh');
      if (!fs.existsSync(scannerPath)) {
        return json(res, 500, { error: 'Scanner script not found', path: scannerPath });
      }

      // Spawn scanner in background (non-blocking)
      const args = domains.flatMap(d => ['-d', d]);
      const child = spawn('bash', [scannerPath, ...args], {
        detached: true,
        stdio: 'ignore',
        cwd: REPORTS_DIR
      });
      child.unref();

      json(res, 202, {
        status: 'accepted',
        message: 'Scan started in background',
        domains,
        pid: child.pid,
        checkReports: '/reports'
      });
    } catch (e) {
      json(res, 400, { error: 'Invalid request', message: e.message });
    }
  }
};

// Simple router
function matchRoute(method, pathname) {
  const key = `${method} ${pathname}`;
  if (routes[key]) return { handler: routes[key], params: {} };

  // Check parameterized routes
  for (const route of Object.keys(routes)) {
    const [routeMethod, routePath] = route.split(' ');
    if (routeMethod !== method) continue;
    if (!routePath.includes(':')) continue;

    const routeParts = routePath.split('/');
    const pathParts = pathname.split('/');
    if (routeParts.length !== pathParts.length) continue;

    const params = {};
    let match = true;
    for (let i = 0; i < routeParts.length; i++) {
      if (routeParts[i].startsWith(':')) {
        params[routeParts[i].slice(1)] = decodeURIComponent(pathParts[i]);
      } else if (routeParts[i] !== pathParts[i]) {
        match = false;
        break;
      }
    }
    if (match) return { handler: routes[route], params };
  }

  return null;
}

// Request handler
const server = http.createServer(async (req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();

  console.log(`[${new Date().toISOString()}] ${method} ${pathname}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (method === 'OPTIONS') {
    res.writeHead(204);
    return res.end();
  }

  const matched = matchRoute(method, pathname);
  if (matched) {
    try {
      await matched.handler(req, res, matched.params);
    } catch (e) {
      console.error('Handler error:', e);
      json(res, 500, { error: 'Internal server error', message: e.message });
    }
  } else {
    json(res, 404, {
      error: 'Not found',
      availableRoutes: Object.keys(routes)
    });
  }
});

server.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════╗
║           light-mcp-server v1.0.0                         ║
╠═══════════════════════════════════════════════════════════╣
║  Server running on http://localhost:${String(PORT).padEnd(5)}                ║
║  Reports directory: ${REPORTS_DIR.slice(0, 35).padEnd(35)} ║
╠═══════════════════════════════════════════════════════════╣
║  Endpoints:                                               ║
║    GET  /health        - Health check                     ║
║    GET  /info          - Server info                      ║
║    GET  /reports       - List reports                     ║
║    GET  /reports/:name - Get specific report              ║
║    POST /echo          - Echo JSON body                   ║
║    POST /scan          - Trigger scan (async)             ║
╚═══════════════════════════════════════════════════════════╝
  `);
});

process.on('SIGINT', () => {
  console.log('\nShutting down...');
  server.close(() => process.exit(0));
});


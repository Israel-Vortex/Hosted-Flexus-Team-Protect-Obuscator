/**
 * /api/loader — bootstrap SIMPLE y fiable para ejecutores Roblox
 * Browser → redirect a la web
 * Executor → devuelve el script protegido (private/script.lua) en text/plain
 *
 * Uso:
 *   loadstring(game:HttpGet("https://TU-DOMINIO.vercel.app/api/loader"))()
 */

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const SECRET = process.env.SCRIPT_SECRET || "FxH_9kQ2mP7wL4nR8tY1uI3oP6aS0dF5gH2jK";
const WEB = (process.env.PUBLIC_WEB_URL || "").replace(/\/$/, "");

function host(req) {
  return req.headers["x-forwarded-host"] || req.headers.host || "localhost";
}
function proto(req) {
  return req.headers["x-forwarded-proto"] || "https";
}
function webUrl(req) {
  if (WEB) return WEB + "/";
  return `${proto(req)}://${host(req)}/`;
}
function h(req, n) {
  return String(req.headers[n.toLowerCase()] || req.headers[n] || "").toLowerCase();
}

function isHostile(req) {
  const accept = h(req, "accept");
  const mode = h(req, "sec-fetch-mode");
  const dest = h(req, "sec-fetch-dest");
  const ua = h(req, "user-agent");
  const secCh = h(req, "sec-ch-ua");
  const purpose = h(req, "purpose") + h(req, "x-purpose");
  const origin = h(req, "origin");
  const referer = h(req, "referer");
  const upgrade = h(req, "upgrade-insecure-requests");
  const flexus = h(req, "x-flexus-client");

  // Navegacion real del browser
  if (mode === "navigate" || dest === "document" || dest === "iframe" || dest === "embed") return true;
  if (secCh) return true;
  if (upgrade === "1" && accept.includes("text/html")) return true;
  if (purpose.includes("prefetch") || purpose.includes("preview")) return true;

  // curl / postman / scrapers
  const tool =
    /curl\/|wget\/|python-requests|python-urllib|postman|insomnia|axios\/|node-fetch|go-http-client|scrapy|httpie|powershell/.test(
      ua
    );
  if (tool && flexus !== "flexus-v3") return true;

  // Browser tipico con HTML
  const hardBrowser =
    ua.includes("mozilla/") &&
    (ua.includes("chrome/") || ua.includes("safari/") || ua.includes("firefox/")) &&
    accept.includes("text/html");
  if (hardBrowser && flexus !== "flexus-v3") return true;

  if (origin.startsWith("http") && flexus !== "flexus-v3") return true;
  if (referer.includes("google.") || referer.includes("bing.") || referer.includes("facebook.")) return true;

  // UA vacia / Roblox HttpGet / executors → OK
  return false;
}

function readScript() {
  const candidates = [
    path.join(process.cwd(), "private", "script.lua"),
    path.join(__dirname, "..", "private", "script.lua"),
    path.join("/var/task", "private", "script.lua"),
  ];
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) {
        const s = fs.readFileSync(p, "utf8");
        if (s && s.length > 20) return s;
      }
    } catch (_) {}
  }
  return null;
}

function secureHeaders(res) {
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, private");
  res.setHeader("X-Robots-Tag", "noindex, nofollow, noarchive");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Content-Type-Options", "nosniff");
  // NO Cross-Origin-Resource-Policy (rompe HttpGet de algunos executors)
}

function redirect(req, res) {
  const url = webUrl(req);
  res.statusCode = 302;
  res.setHeader("Location", url);
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.end(
    `<!doctype html><html><head><meta http-equiv="refresh" content="0;url=${url}"><title>FlexusHub</title></head><body style="background:#0a0a0c;color:#eee;font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0"><p>Redirigiendo a <a href="${url}" style="color:#9cf">FlexusHub</a>…</p></body></html>`
  );
}

module.exports = function handler(req, res) {
  secureHeaders(res);
  if (req.method === "OPTIONS") {
    res.statusCode = 204;
    return res.end();
  }

  // Browser → web
  if (isHostile(req)) {
    return redirect(req, res);
  }

  const source = readScript();
  if (!source) {
    res.statusCode = 500;
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    return res.end('--[FlexusHub] script missing on server');
  }

  // Marker + script (text/plain para que HttpGet/loadstring funcionen siempre)
  const marker =
    "--[[FLEXUS:" +
    crypto.createHmac("sha256", SECRET).update(String(Date.now())).digest("hex").slice(0, 12) +
    "]]\n";

  res.statusCode = 200;
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("X-Flexus-OK", "1");
  return res.end(marker + source);
};

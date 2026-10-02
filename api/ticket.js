/** GET /api/ticket — mint short-lived IP-tagged ticket */

const crypto = require("crypto");

const SECRET = process.env.SCRIPT_SECRET || "FxH_9kQ2mP7wL4nR8tY1uI3oP6aS0dF5gH2jK";
const WEB = (process.env.PUBLIC_WEB_URL || "").replace(/\/$/, "");
const TTL = Number(process.env.TICKET_TTL || 35);
const CHUNKS = 4;

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
function clientIp(req) {
  const xf = req.headers["x-forwarded-for"];
  if (typeof xf === "string" && xf.length) return xf.split(",")[0].trim();
  return req.headers["x-real-ip"] || req.socket?.remoteAddress || "0.0.0.0";
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
  const via = h(req, "via");
  const fwd = h(req, "forwarded");

  if (mode === "navigate" || dest === "document" || dest === "iframe" || dest === "embed") return true;
  if (accept.includes("text/html") || accept.includes("application/xhtml")) return true;
  if (upgrade === "1") return true;
  if (purpose.includes("prefetch") || purpose.includes("preview")) return true;
  if (secCh) return true;

  // Tools explicitas de robo (curl/postman/python). NO bloquear UA vacia/Roblox (HttpGet).
  const tool =
    /curl\/|wget\/|python-requests|python-urllib|postman|insomnia|axios\/|node-fetch|go-http-client|scrapy|httpie|powershell/.test(
      ua
    );

  // Navegador real: mozilla+chrome/safari con señales web
  const hardBrowser =
    (ua.includes("mozilla/") &&
      (ua.includes("chrome/") || ua.includes("safari/") || ua.includes("firefox/"))) &&
    (secCh || mode || dest || upgrade === "1" || accept.includes("text/html"));

  if (origin.startsWith("http") && flexus !== "flexus-v3") return true;
  if (referer.includes("google.") || referer.includes("bing.") || referer.includes("facebook.")) return true;
  if (tool && flexus !== "flexus-v3") return true;
  if (hardBrowser && flexus !== "flexus-v3") return true;

  return false;
}

function redirect(req, res) {
  res.writeHead(302, {
    Location: webUrl(req),
    "Cache-Control": "no-store, no-cache, must-revalidate, private",
    "X-Robots-Tag": "noindex, nofollow, noarchive",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
  });
  return res.end();
}

function deny(res) {
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("X-Robots-Tag", "noindex");
  return res.status(403).send("--");
}

function secureHeaders(res) {
  res.setHeader("Cache-Control", "no-store, no-cache, must-revalidate, private");
  res.setHeader("X-Robots-Tag", "noindex, nofollow, noarchive");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Access-Control-Allow-Origin", "null");
  res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
}

function b64url(buf) {
  return Buffer.from(buf)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}
function fromB64url(s) {
  s = String(s).replace(/-/g, "+").replace(/_/g, "/");
  while (s.length % 4) s += "=";
  return Buffer.from(s, "base64");
}

/** ticket = ts.ipHash.nonce.sig */
function mintTicket(ip) {
  const ts = Math.floor(Date.now() / 1000);
  const nonce = crypto.randomBytes(16).toString("hex");
  const ipHash = crypto.createHmac("sha256", SECRET).update("ip:" + ip).digest("hex").slice(0, 16);
  const payload = `${ts}.${ipHash}.${nonce}`;
  const sig = crypto.createHmac("sha256", SECRET).update("ticket:v3:" + payload).digest("hex");
  return `${payload}.${sig}`;
}

function verifyTicket(ticket, ip) {
  try {
    const parts = String(ticket || "").split(".");
    if (parts.length !== 4) return null;
    const [tsStr, ipHash, nonce, sig] = parts;
    const ts = parseInt(tsStr, 10);
    if (!ts || !ipHash || !nonce || !sig) return null;
    const now = Math.floor(Date.now() / 1000);
    if (now - ts > TTL || ts - now > 5) return null;
    const payload = `${tsStr}.${ipHash}.${nonce}`;
    const expect = crypto.createHmac("sha256", SECRET).update("ticket:v3:" + payload).digest("hex");
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expect))) return null;
    const ipExpect = crypto.createHmac("sha256", SECRET).update("ip:" + ip).digest("hex").slice(0, 16);
    // IP soft-bind: allow if match; if proxy changes IP, still require valid sig+time
    // Strict mode when STRICT_IP=1
    if (process.env.STRICT_IP === "1" && ipHash !== ipExpect) return null;
    return { ts, ipHash, nonce, payload };
  } catch {
    return null;
  }
}

/** Derive per-ticket AES key + XOR stream seed */
function deriveKeys(ticketPayload) {
  const material = crypto.createHmac("sha256", SECRET).update("keys:v3:" + ticketPayload).digest();
  return {
    aesKey: material.slice(0, 32),
    ivSeed: material.slice(16, 32),
  };
}

function encryptScript(plain, ticketPayload) {
  const { aesKey } = deriveKeys(ticketPayload);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", aesKey, iv);
  const enc = Buffer.concat([cipher.update(Buffer.from(plain, "utf8")), cipher.final()]);
  const tag = cipher.getAuthTag();
  // pack: iv(12) + tag(16) + ciphertext
  return Buffer.concat([iv, tag, enc]);
}

function splitChunks(buf, n) {
  const out = [];
  const size = Math.ceil(buf.length / n);
  for (let i = 0; i < n; i++) {
    out.push(buf.slice(i * size, Math.min(buf.length, (i + 1) * size)));
  }
  return out;
}

function decoyLua() {
  return `--[[ unauthorized ]]\nwarn("[FlexusHub] invalid session")\nreturn\n`;
}

module.exports = function handler(req, res) {
  secureHeaders(res);
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "GET" && req.method !== "POST") return deny(res);
  if (isHostile(req)) return redirect(req, res);

  const ticket = mintTicket(clientIp(req));
  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  return res.status(200).send(ticket);
};

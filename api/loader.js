/**
 * /api/loader — bootstrap ofuscado
 * Browser → redirect web
 * Executor → Lua que: ticket → 4 chunks cifrados → decrypt AES → loadstring
 */

const crypto = require("crypto");

const SECRET = process.env.SCRIPT_SECRET || "FxH_9kQ2mP7wL4nR8tY1uI3oP6aS0dF5gH2jK";
const WEB = (process.env.PUBLIC_WEB_URL || "").replace(/\/$/, "");
const TTL = Number(process.env.TICKET_TTL || 120);
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

  // Solo navegador real (navegacion / document)
  if (mode === "navigate" || dest === "document" || dest === "iframe" || dest === "embed") return true;
  if (secCh) return true; // Chrome client hints = browser
  if (upgrade === "1" && accept.includes("text/html")) return true;
  if (purpose.includes("prefetch") || purpose.includes("preview")) return true;

  // Tools de scraping (no executors)
  const tool =
    /curl\/|wget\/|python-requests|python-urllib|postman|insomnia|axios\/|node-fetch|go-http-client|scrapy|httpie|powershell/.test(
      ua
    );
  if (tool && flexus !== "flexus-v3") return true;

  // Browser UA + HTML accept (sin bloquear Accept generico de executors)
  const hardBrowser =
    ua.includes("mozilla/") &&
    (ua.includes("chrome/") || ua.includes("safari/") || ua.includes("firefox/")) &&
    accept.includes("text/html");
  if (hardBrowser && flexus !== "flexus-v3") return true;

  if (origin.startsWith("http") && flexus !== "flexus-v3") return true;
  if (referer.includes("google.") || referer.includes("bing.") || referer.includes("facebook.")) return true;

  // UA vacia / Roblox / executor custom → permitido
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

  const base = `${proto(req)}://${host(req)}`;

  // Loader Lua ofuscado (nombres cortos, sin secretos)
  const lua = `--[[FLEXUS]]local a,b,c,d,e=game,("${base}"),(syn or{}),request,http_request
local function R(u,ex)
local H={["User-Agent"]="FlexusExecutor/3.0",["X-Flexus-Client"]="flexus-v3",["Accept"]="application/octet-stream"}
if ex then for k,v in pairs(ex)do H[k]=v end end
local ok,r=pcall(function()
if a and a.request then return a.request({Url=u,Method="GET",Headers=H})end
if syn and syn.request then return syn.request({Url=u,Method="GET",Headers=H})end
if e then return e({Url=u,Method="GET",Headers=H})end
if d then return d({Url=u,Method="GET",Headers=H})end
if http and http.request then return http.request({Url=u,Method="GET",Headers=H})end
return nil
end)
if ok and r then local bd=r.Body or r.body local cd=tonumber(r.StatusCode or r.status_code or 0)or 0
if bd and cd==200 and #tostring(bd)>0 then return tostring(bd)end end
local ok2,bd2=pcall(function()return game:HttpGet(u)end)
if ok2 and bd2 and #tostring(bd2)>0 then return tostring(bd2)end
return nil
end
local function B64(s)
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
s=s:gsub('-','+'):gsub('_','/')
local t=''
local function c(x)return b:find(x,1,true)or 1 end
s=s..string.rep('=',(4-#s%4)%4)
for i=1,#s,4 do
local n=(c(s:sub(i,i))-1)*262144+(c(s:sub(i+1,i+1))-1)*4096+(c(s:sub(i+2,i+2))-1)*64+(c(s:sub(i+3,i+3))-1)
t=t..string.char(math.floor(n/65536)%256,math.floor(n/256)%256,n%256)
end
local pad=(s:sub(-2)=='=='and 2)or(s:sub(-1)=='='and 1)or 0
if pad>0 then t=t:sub(1,-(pad+1))end
return t
end
-- 1) ticket
local tb=R(b.."/api/ticket")
if not tb or #tb<20 or tb:sub(1,2)=="--" then return warn("[FlexusHub] auth fail (ticket)") end
local ticket=tb:gsub("%s+","")
-- 2) unwrap plaintext (ticket-bound, browser blocked)
local plain=R(b.."/api/unwrap?k="..ticket,{["X-Flexus-Ticket"]=ticket,["X-Flexus-Client"]="flexus-v3"})
if (not plain or #plain<30 or plain:sub(1,2)=="--") then
  -- fallback sin headers custom (algunos executors no pasan headers)
  plain=R(b.."/api/unwrap?k="..ticket)
end
if not plain or #plain<30 or plain:sub(1,2)=="--" then return warn("[FlexusHub] unwrap fail") end
local fn,err=loadstring(plain)
if not fn then return warn("[FlexusHub] compile: "..tostring(err)) end
return fn()

`

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  return res.status(200).send(lua);
};

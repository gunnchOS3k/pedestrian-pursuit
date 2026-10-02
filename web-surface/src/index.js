const SHA = "8eeb5051d70fab7fc9339a1fef6272e943df1be1";
const PREFIX = `pursuit/${SHA}/`;

const FILES = {
  "index.apple-touch-icon.png": { bytes: 10335, sha256: "2fa37c90392db27b8cfb77dc0689de5d1f0bdc92ab80d5980cd5cff24b2dbb14" },
  "index.audio.position.worklet.js": { bytes: 2973, sha256: "be33985bc7160d6bf9646f259cd86b259cd67b02ccb297ee5c44f8ac84327bc8" },
  "index.audio.worklet.js": { bytes: 7298, sha256: "5b476a9c9ce642c0ee4256436d1bc31d9c38f868aca0f9a8e2a57c18d2dec2a3" },
  "index.html": { bytes: 5449, sha256: "f33cc6143a769bf0e5411f634441229e7cbae6a00169a8f4f482e221d7ff4292" },
  "index.icon.png": { bytes: 24966, sha256: "26ae33aacbc5cc6b2aa783717bf02e7a7d3113fbcdfccd87b194122369150963" },
  "index.js": { bytes: 358024, sha256: "6f74d38f35066e0fd6e9b9f265af4c88a36f113726de9fbba9b50dd939bf7b2e" },
  "index.pck": { bytes: 43130240, sha256: "2b8327a628f3f9feaf53e05f38caaa36e5cfc15ae75e7e4cf92589ab71878902" },
  "index.png": { bytes: 18543, sha256: "d29f2916a26619b43d54a2cdec1585e9b7f7201608e42c81e7ea0f1e1ebfd636" },
  "index.wasm": { bytes: 37334478, sha256: "e68cbce74b58c38d58b75806ab1a7dbecbc0345e5332e40ed8264aa5b955e4fc" },
};

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".png": "image/png",
};

export function runtimeManifest() {
  return {
    channel: "DEVELOPMENT",
    release_channel: "DEVELOPMENT",
    label: "DEVELOPMENT_BUILD",
    repo: "gunnchOS3k/pedestrian-pursuit",
    ref: "main",
    source_ref: "main",
    sha: SHA,
    source_sha: SHA,
    acceptedMain: true,
    HUMAN_COURSE_APPROVAL: false,
    HUMAN_FUN_APPROVAL: false,
    godot: "4.5.2.stable.official",
    exportPreset: "Web",
    threads: true,
    isolation: "COOP-COEP",
    bucket: "gunnchos-game-runtimes-staging",
    prefix: PREFIX,
    servedIndexHtmlAddsDevelopmentBanner: true,
    files: FILES,
  };
}

function mimeFor(name) {
  const dot = name.lastIndexOf(".");
  return MIME[dot >= 0 ? name.slice(dot) : ""] || "application/octet-stream";
}

function isolation(headers) {
  headers.set("Cross-Origin-Opener-Policy", "same-origin");
  headers.set("Cross-Origin-Embedder-Policy", "require-corp");
  headers.set("Cross-Origin-Resource-Policy", "same-origin");
}

function withBanner(html) {
  const banner = `<div id="dev-watermark" style="position:fixed;top:0;left:0;z-index:50;pointer-events:none;background:#111;color:#fff;font:12px sans-serif;padding:4px 8px">DEVELOPMENT BUILD ${SHA.slice(0, 12)}</div>`;
  return html.includes("<body>") ? html.replace("<body>", `<body>${banner}`) : banner + html;
}

async function serveRuntime(request, env, name) {
  if (!Object.prototype.hasOwnProperty.call(FILES, name)) {
    return new Response("not found", { status: 404 });
  }
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("method not allowed", { status: 405, headers: { allow: "GET, HEAD" } });
  }
  const key = PREFIX + name;
  const rangeHeader = request.headers.get("range");
  const object = request.method === "HEAD"
    ? await env.RUNTIME.head(key)
    : await env.RUNTIME.get(key, rangeHeader ? { range: request.headers } : undefined);
  if (!object) {
    return new Response(rangeHeader ? "range not satisfiable" : "not found", { status: rangeHeader ? 416 : 404 });
  }
  const headers = new Headers();
  headers.set("content-type", mimeFor(name));
  headers.set("cache-control", "public, max-age=31536000, immutable");
  headers.set("accept-ranges", "bytes");
  headers.set("etag", object.httpEtag);
  isolation(headers);
  const partial = Boolean(rangeHeader && object.range);
  const status = partial ? 206 : 200;
  if (partial) {
    const start = object.range.offset;
    const end = object.range.offset + object.range.length - 1;
    headers.set("content-range", `bytes ${start}-${end}/${object.size}`);
    headers.set("content-length", String(object.range.length));
  } else {
    headers.set("content-length", String(object.size));
  }
  if (request.method === "HEAD") {
    return new Response(null, { status, headers });
  }
  if (name === "index.html") {
    const html = withBanner(await new Response(object.body).text());
    headers.delete("content-length");
    headers.set("cache-control", "public, max-age=300");
    return new Response(html, { status: 200, headers });
  }
  return new Response(object.body, { status, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/runtime-manifest") {
      return new Response(JSON.stringify(runtimeManifest(), null, 2), {
        headers: {
          "content-type": "application/json; charset=utf-8",
          "cache-control": "no-store",
        },
      });
    }
    const runtimeRoot = `/runtime/${SHA}/`;
    if (url.pathname.startsWith("/runtime/")) {
      if (!url.pathname.startsWith(runtimeRoot) || url.pathname.slice(runtimeRoot.length).includes("/")) {
        return new Response("not found", { status: 404 });
      }
      return serveRuntime(request, env, decodeURIComponent(url.pathname.slice(runtimeRoot.length)));
    }
    return env.ASSETS.fetch(request);
  },
};

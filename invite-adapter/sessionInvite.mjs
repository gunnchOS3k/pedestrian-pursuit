/**
 * Pure invite join adapter for Pedestrian Pursuit.
 *
 * Checked copy of the invite rules in anime-aggressors pull request 131,
 * packages/invite-contract:
 * https://github.com/gunnchOS3k/anime-aggressors/pull/131
 * This file does not import that package. It does not open a socket or deploy a route.
 * Game mode label: pedestrian race.
 */

export const GAME_MODE = "pedestrian race";

export const INVITE_ORIGIN = "https://gunnchos.com";
export const INVITE_PATH_PREFIX = "/i/";
export const OPAQUE_TOKEN_BYTES = 32;

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

function bytesLookUnguessable(bytes) {
  if (bytes.length !== OPAQUE_TOKEN_BYTES) return false;
  const distinct = new Set(bytes).size;
  if (distinct < 16) return false;
  let monotonic = true;
  for (let i = 1; i < bytes.length; i += 1) {
    const step = (bytes[i] - bytes[i - 1] + 256) % 256;
    if (step !== 1) {
      monotonic = false;
      break;
    }
  }
  return !monotonic;
}

export function opaqueTokenFromBytes(bytes) {
  if (!bytesLookUnguessable(bytes)) return null;
  const token = Buffer.from(bytes).toString("base64url");
  if (!TOKEN_PATTERN.test(token)) return null;
  return token;
}

export function isOpaqueInviteToken(token) {
  if (!TOKEN_PATTERN.test(token)) return false;
  const bytes = Buffer.from(token, "base64url");
  if (bytes.length !== OPAQUE_TOKEN_BYTES) return false;
  return bytesLookUnguessable(bytes);
}

export function inviteUrlForToken(token) {
  if (!isOpaqueInviteToken(token)) return { ok: false, reason: "token" };
  return { ok: true, url: `${INVITE_ORIGIN}${INVITE_PATH_PREFIX}${token}` };
}

export function parseInviteUrl(raw) {
  if (raw.includes("%") || raw.includes("\\") || /\s/.test(raw)) {
    return { ok: false, reason: "encoded_or_whitespace" };
  }
  let url;
  try {
    url = new URL(raw);
  } catch {
    return { ok: false, reason: "malformed_url" };
  }
  if (url.protocol !== "https:") return { ok: false, reason: "not_https" };
  if (url.username || url.password) return { ok: false, reason: "userinfo" };
  if (url.hostname !== "gunnchos.com") return { ok: false, reason: "wrong_host" };
  if (url.port || raw.startsWith("https://gunnchos.com:")) return { ok: false, reason: "port" };
  if (url.search) return { ok: false, reason: "query" };
  if (url.hash) return { ok: false, reason: "fragment" };
  const parts = url.pathname.split("/").filter((part) => part.length > 0);
  if (parts.length !== 2 || parts[0] !== "i") return { ok: false, reason: "path" };
  const token = parts[1];
  if (!isOpaqueInviteToken(token)) return { ok: false, reason: "token" };
  return { ok: true, token };
}

/**
 * @param {string} token
 * @param {{ id: string, expiresAt: number, revoked: boolean, used: boolean, capacity: number }} session
 * @param {number} nowMs
 */
export function joinFromInvite(token, session, nowMs) {
  if (!isOpaqueInviteToken(token)) return { ok: false, error: "malformed" };
  if (session.revoked) return { ok: false, error: "revoked" };
  if (!(session.expiresAt > nowMs)) return { ok: false, error: "expired" };
  if (session.used) return { ok: false, error: "replayed" };
  if (!(Number.isFinite(session.capacity) && session.capacity > 0)) {
    return { ok: false, error: "full" };
  }
  const url = inviteUrlForToken(token);
  if (!url.ok) return { ok: false, error: "malformed" };
  const canonical = `${INVITE_ORIGIN}${INVITE_PATH_PREFIX}${token}`;
  if (url.url !== canonical) return { ok: false, error: "malformed" };
  return { ok: true, sessionId: session.id, mode: GAME_MODE, url: url.url };
}

/**
 * Host and client are seats on an already accepted invite. This does not
 * open a socket. A browser that cannot write the clipboard still returns
 * the HTTPS URL for the person to copy.
 * @param {string} token
 * @param {{ id: string, expiresAt: number, revoked: boolean, used: boolean, capacity: number, hostClaimed?: boolean }} session
 * @param {number} nowMs
 * @param {"host" | "client"} role
 */
export function assignSeat(token, session, nowMs, role) {
  if (role !== "host" && role !== "client") return { ok: false, error: "role" };
  const joined = joinFromInvite(token, session, nowMs);
  if (!joined.ok) return joined;
  if (role === "host" && session.hostClaimed) return { ok: false, error: "host_taken" };
  return {
    ok: true,
    sessionId: joined.sessionId,
    mode: joined.mode,
    url: joined.url,
    role,
  };
}

export function browserInviteFallback(token) {
  const url = inviteUrlForToken(token);
  if (!url.ok) return { ok: false, reason: url.reason };
  return { ok: true, url: url.url, copy: "manual", clipboard: false };
}

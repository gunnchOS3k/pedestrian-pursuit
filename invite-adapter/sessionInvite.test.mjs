import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  GAME_MODE,
  inviteUrlForToken,
  assignSeat,
  browserInviteFallback,
  joinFromInvite,
  opaqueTokenFromBytes,
  parseInviteUrl,
} from "./sessionInvite.mjs";

const NOW = 1_700_000_000_000;
const LATER = NOW + 60_000;
const SESSION_ID = "pedestrian-race-session";
const ANIME_SEED_3 = "Plt4lbLP7AkmQ2B9mrfU8Q4rSGWCn7zZ9hMwTWqHpME";

function tokenFromSeed(seed) {
  const bytes = new Uint8Array(32);
  for (let i = 0; i < bytes.length; i += 1) {
    bytes[i] = (seed * 17 + i * 29 + 11) & 0xff;
  }
  const token = opaqueTokenFromBytes(bytes);
  assert.ok(token, `seed ${seed} was not an opaque token`);
  return token;
}

function openSession(overrides = {}) {
  return {
    id: SESSION_ID,
    expiresAt: LATER,
    revoked: false,
    used: false,
    capacity: 2,
    ...overrides,
  };
}

describe("Pedestrian Pursuit invite adapter", () => {
  it("matches the anime contract token for seed 3 and keeps the session id off the URL", () => {
    assert.equal(tokenFromSeed(3), ANIME_SEED_3);
    const token = tokenFromSeed(3);
    const joined = joinFromInvite(token, openSession(), NOW + 1);
    assert.equal(joined.ok, true);
    if (!joined.ok) return;
    assert.equal(joined.sessionId, SESSION_ID);
    assert.equal(joined.mode, "pedestrian race");
    assert.equal(GAME_MODE, "pedestrian race");
    assert.equal(joined.url, `https://gunnchos.com/i/${token}`);
    assert.equal(joined.url.includes(SESSION_ID), false);
    assert.equal(joined.url.includes(String(LATER)), false);
    assert.equal(joined.url.includes("?"), false);
    assert.equal(joined.url.includes("#"), false);
    const parsed = parseInviteUrl(joined.url);
    assert.deepEqual(parsed, { ok: true, token });
  });

  it("rejects the same guessable tokens and extra-state URLs as the anime contract", () => {
    assert.equal(opaqueTokenFromBytes(new Uint8Array(32)), null);
    assert.equal(opaqueTokenFromBytes(Uint8Array.from({ length: 32 }, (_, i) => i)), null);
    assert.equal(inviteUrlForToken("ROOMCODE").ok, false);
    assert.deepEqual(joinFromInvite("ROOMCODE", openSession(), NOW + 1), {
      ok: false,
      error: "malformed",
    });

    const token = tokenFromSeed(9);
    const cases = [
      [`http://gunnchos.com/i/${token}`, "not_https"],
      [`https://user:secret@gunnchos.com/i/${token}`, "userinfo"],
      [`https://www.gunnchos.com/i/${token}`, "wrong_host"],
      [`https://gunnchos.com:443/i/${token}`, "port"],
      [`https://gunnchos.com/i/${token}?seat=1&name=Ada`, "query"],
      [`https://gunnchos.com/i/${token}#save=1`, "fragment"],
      [`https://gunnchos.com/i/${token}/extra`, "path"],
      [`https://evil.example/i/${token}`, "wrong_host"],
      [`https://gunnchos.com/i/${token.slice(0, 20)}%2Fadmin`, "encoded_or_whitespace"],
    ];
    for (const [raw, reason] of cases) {
      assert.deepEqual(parseInviteUrl(raw), { ok: false, reason }, raw);
    }
  });

  it("returns expired, revoked, replayed, and full without putting those facts in a URL", () => {
    const token = tokenFromSeed(4);
    assert.deepEqual(joinFromInvite(token, openSession({ expiresAt: NOW }), NOW), {
      ok: false,
      error: "expired",
    });
    assert.deepEqual(joinFromInvite(token, openSession({ revoked: true, expiresAt: NOW }), NOW + 1), {
      ok: false,
      error: "revoked",
    });
    assert.deepEqual(joinFromInvite(token, openSession({ used: true, capacity: 0 }), NOW + 1), {
      ok: false,
      error: "replayed",
    });
    const full = joinFromInvite(token, openSession({ capacity: 0 }), NOW + 1);
    assert.deepEqual(full, { ok: false, error: "full" });
    assert.equal(Object.hasOwn(full, "url"), false);
    assert.equal(Object.hasOwn(full, "sessionId"), false);
  });

  it("can accept eight distinct contract tokens without treating that as a deployed invite route", () => {
    const urls = new Set();
    for (let i = 0; i < 8; i += 1) {
      const token = tokenFromSeed(20 + i);
      const sessionId = `${SESSION_ID}-${i}`;
      const joined = joinFromInvite(token, openSession({ id: sessionId }), NOW + 1);
      assert.equal(joined.ok, true, JSON.stringify(joined));
      if (!joined.ok) return;
      assert.equal(joined.url.includes(sessionId), false);
      urls.add(joined.url);
    }
    assert.equal(urls.size, 8);
  });

  it("assigns host and client seats and returns a manual copy link", () => {
    const token = tokenFromSeed(11);
    const host = assignSeat(token, openSession(), NOW + 1, "host");
    assert.equal(host.ok, true);
    if (!host.ok) return;
    assert.equal(host.role, "host");
    assert.equal(host.url.includes("?"), false);
    const client = assignSeat(token, openSession({ id: host.sessionId, hostClaimed: true }), NOW + 1, "client");
    assert.equal(client.ok, true);
    if (!client.ok) return;
    assert.equal(client.role, "client");
    assert.equal(client.sessionId, host.sessionId);
    assert.deepEqual(assignSeat(token, openSession({ hostClaimed: true }), NOW + 1, "host"), {
      ok: false,
      error: "host_taken",
    });
    assert.deepEqual(assignSeat(token, openSession(), NOW + 1, "spectator"), {
      ok: false,
      error: "role",
    });
    const copy = browserInviteFallback(token);
    assert.equal(copy.ok, true);
    if (!copy.ok) return;
    assert.equal(copy.copy, "manual");
    assert.equal(copy.clipboard, false);
    assert.equal(copy.url, host.url);
    assert.equal(browserInviteFallback("ROOMCODE").ok, false);
  });

});

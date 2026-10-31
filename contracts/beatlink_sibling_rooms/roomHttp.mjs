/** One room authority for the HTTP lifecycle and RoomManager. No sockets and no listen. */

import { randomBytes } from 'node:crypto';
import { addMember, createParty, disconnectMember, endParty } from './partyLifecycle.mjs';

export const roomAuthority = {
  parties: new Map(),
  hostSessions: new Map(),
  memberSessions: new Map(),
  expiresAt: new Map(),
};

let nowFn = () => Date.now();

export function setAuthorityClock(fn) {
  nowFn = typeof fn === 'function' ? fn : () => Date.now();
}

export function resetAuthority() {
  roomAuthority.parties.clear();
  roomAuthority.hostSessions.clear();
  roomAuthority.memberSessions.clear();
  roomAuthority.expiresAt.clear();
  nowFn = () => Date.now();
}

export function invalidateAuthority(code) {
  const key = String(code || '').toUpperCase();
  roomAuthority.parties.delete(key);
  roomAuthority.hostSessions.delete(key);
  roomAuthority.expiresAt.delete(key);
  for (const [session, record] of roomAuthority.memberSessions) {
    if (record.code === key) roomAuthority.memberSessions.delete(session);
  }
}

export function invalidateMember(code, memberId) {
  const key = String(code || '').toUpperCase();
  for (const [session, record] of roomAuthority.memberSessions) {
    if (record.code === key && record.memberId === memberId) roomAuthority.memberSessions.delete(session);
  }
}

export function publicParty(party) {
  if (!party) return null;
  return {
    code: party.code,
    phase: party.phase,
    hostId: party.hostId,
    members: party.members.map((member) => ({ id: member.id, role: member.role, connected: member.connected })),
  };
}

function partyAt(code) {
  return roomAuthority.parties.get(String(code || '').toUpperCase()) ?? null;
}

function expired(code) {
  const expiresAt = roomAuthority.expiresAt.get(code);
  return typeof expiresAt === 'number' && nowFn() > expiresAt;
}

export function createRoomHttp({ code, hostId, ttlMs = 7_200_000 }) {
  const party = createParty({ code, hostId });
  const hostSession = randomBytes(32).toString('hex');
  roomAuthority.parties.set(party.code, party);
  roomAuthority.hostSessions.set(party.code, hostSession);
  roomAuthority.expiresAt.set(party.code, nowFn() + ttlMs);
  return { status: 200, body: { party: publicParty(party), hostSession } };
}

export function joinRoomHttp(code) {
  const key = String(code || '').toUpperCase();
  const party = partyAt(key);
  if (!party) return { status: 404, body: { error: 'Room not found' } };
  if (expired(key)) {
    invalidateAuthority(key);
    return { status: 410, body: { error: 'Room expired' } };
  }
  const memberId = `member-${randomBytes(8).toString('hex')}`;
  const next = addMember(party, memberId);
  if (!next || next === party) return { status: 409, body: { error: 'Room is closed' } };
  const memberSession = randomBytes(32).toString('hex');
  roomAuthority.memberSessions.set(memberSession, { code: key, memberId });
  roomAuthority.parties.set(key, next);
  return { status: 200, body: { party: publicParty(next), memberSession } };
}

export function disconnectRoomHttp(code, presentedSession) {
  const key = String(code || '').toUpperCase();
  const party = partyAt(key);
  if (!party) return { status: 404, body: { error: 'Room not found' } };
  if (expired(key)) {
    invalidateAuthority(key);
    return { status: 410, body: { error: 'Room expired' } };
  }
  const session = String(presentedSession || '');
  if (session && session === roomAuthority.hostSessions.get(key)) {
    roomAuthority.hostSessions.delete(key);
    return { status: 200, body: { party: publicParty(party) } };
  }
  const record = roomAuthority.memberSessions.get(session);
  if (!record || record.code !== key) return { status: 403, body: { error: 'Member session required' } };
  roomAuthority.memberSessions.delete(session);
  const next = disconnectMember(party, record.memberId);
  if (!next) return { status: 404, body: { error: 'Room not found' } };
  roomAuthority.parties.set(key, next);
  return { status: 200, body: { party: publicParty(next) } };
}

export function readPartyHttp(code, presentedSession) {
  const key = String(code || '').toUpperCase();
  const party = partyAt(key);
  if (!party) return { status: 404, body: { error: 'Room not found' } };
  if (expired(key)) {
    invalidateAuthority(key);
    return { status: 410, body: { error: 'Room expired' } };
  }
  const session = String(presentedSession || '');
  const hostMatch = session && session === roomAuthority.hostSessions.get(key);
  const member = roomAuthority.memberSessions.get(session);
  if (!hostMatch && (!member || member.code !== key)) {
    return { status: 403, body: { error: 'Session required' } };
  }
  return { status: 200, body: { party: publicParty(party) } };
}

export function endRoomHttp(code, presentedHostSession) {
  const key = String(code || '').toUpperCase();
  const party = partyAt(key);
  if (!party) return { status: 404, body: { error: 'Room not found' } };
  if (expired(key)) {
    invalidateAuthority(key);
    return { status: 410, body: { error: 'Room expired' } };
  }
  const hostSession = roomAuthority.hostSessions.get(key);
  if (!hostSession || presentedHostSession !== hostSession) {
    return { status: 403, body: { error: 'Host session required' } };
  }
  const next = endParty(party, party.hostId);
  if (!next) return { status: 403, body: { error: 'Host session required' } };
  roomAuthority.parties.set(key, next);
  invalidateAuthority(key);
  roomAuthority.parties.set(key, next);
  return { status: 200, body: { party: publicParty(next) } };
}

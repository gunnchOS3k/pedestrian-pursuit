/** Versioned game-session contract bound to the room transport. It does not play a race by itself. */

import { createHash, randomBytes } from 'node:crypto';
import { createRoomHttp, joinRoomHttp } from './roomHttp.mjs';

export const GAME_SESSION_CONTRACT_NAME = 'gunnchos.beatlink.game_session';
export const GAME_SESSION_CONTRACT_VERSION = 1;
export const PEDESTRIAN_PURSUIT_APPLICATION_ID = 'pedestrian-pursuit';
export const RACE_RUNTIME_PRODUCER = 'pedestrian-pursuit-race-runtime';
const DRIVE_BOUND_MSEC = 150000;

const sessions = new Map();
const invitations = new Map();
const sessionsBySecret = new Map();

function secret() {
  return randomBytes(32).toString('hex');
}

function prefixedId(prefix) {
  return `${prefix}-${randomBytes(8).toString('hex')}`;
}

function roomCode() {
  return randomBytes(4).toString('hex').slice(0, 5).toUpperCase();
}

function assertNoSecret(value, hostSession) {
  if (hostSession && JSON.stringify(value).includes(hostSession)) {
    throw new Error('HOST_SESSION_LEAKED');
  }
  return value;
}

function note(record, channel, name, fields) {
  const entry = assertNoSecret(
    {
      name,
      applicationId: record.applicationId,
      roomCode: record.roomCode,
      ...fields,
    },
    record.hostSession,
  );
  record[channel].push(entry);
}

function publicSession(record) {
  return assertNoSecret(
    {
      contract: GAME_SESSION_CONTRACT_NAME,
      version: GAME_SESSION_CONTRACT_VERSION,
      applicationId: record.applicationId,
      roomCode: record.roomCode,
      hostId: record.hostId,
      phase: record.phase,
      memberId: record.memberId,
      guestConnected: record.guestConnected,
    },
    record.hostSession,
  );
}

function publicEvent(record, event) {
  return assertNoSecret(
    {
      type: event.type,
      eventId: event.eventId,
      applicationId: record.applicationId,
      roomCode: record.roomCode,
      choice: event.choice ?? null,
      result: event.result ?? null,
      acknowledgements: { host: event.acknowledgements.host, guest: event.acknowledgements.guest },
    },
    record.hostSession,
  );
}

export function resetGameSessions() {
  sessions.clear();
  invitations.clear();
  sessionsBySecret.clear();
}

export function runtimeRaceDigest(result) {
  const canonical = {
    applicationId: result.applicationId,
    roomCode: result.roomCode,
    courseId: result.courseId,
    hostMemberId: result.hostMemberId,
    guestMemberId: result.guestMemberId,
    lapsCompleted: result.lapsCompleted,
    checkpointCrossings: result.checkpointCrossings,
    drivenMsec: result.drivenMsec,
    finishOrder: result.finishOrder,
    bothFinished: result.bothFinished,
    producedBy: result.producedBy,
    sourceLog: result.sourceLog,
  };
  return createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
}

export function openGameSession({ applicationId, roomCode, hostId, hostSession }) {
  if (applicationId !== PEDESTRIAN_PURSUIT_APPLICATION_ID) {
    return { status: 400, error: 'Unsupported application' };
  }
  const code = String(roomCode || '').trim().toUpperCase();
  if (!code || code === applicationId || code === PEDESTRIAN_PURSUIT_APPLICATION_ID.toUpperCase()) {
    return { status: 400, error: 'Room code is separate from the application' };
  }
  if (sessions.has(code)) return { status: 409, error: 'Room already open' };
  const publicHostId = hostId ? String(hostId) : prefixedId('host');
  const issuedHostSession = hostSession ? String(hostSession) : secret();
  const invitation = prefixedId('inv');
  if (publicHostId === issuedHostSession || invitation === issuedHostSession) {
    return { status: 400, error: 'Host id is not the host session' };
  }
  const record = {
    applicationId,
    roomCode: code,
    hostId: publicHostId,
    hostSession: issuedHostSession,
    invitation,
    memberId: null,
    memberSession: null,
    guestConnected: false,
    phase: 'lobby',
    events: [],
    logs: [],
    telemetry: [],
    runtimeResult: null,
  };
  sessions.set(code, record);
  invitations.set(invitation, code);
  sessionsBySecret.set(issuedHostSession, { roomCode: code, role: 'host' });
  note(record, 'logs', 'session_opened', { hostId: publicHostId });
  note(record, 'telemetry', 'session_opened', { hostId: publicHostId });
  return { status: 200, hostSession: issuedHostSession, invitation, session: publicSession(record) };
}

export function openGameSessionOnRoom(applicationId) {
  const hostId = prefixedId('host');
  const code = roomCode();
  const room = createRoomHttp({ code, hostId });
  if (room.status !== 200 || !room.body?.party || !room.body.hostSession) {
    return { status: 502, error: 'Room transport did not create a room' };
  }
  if (room.body.party.hostId !== hostId || room.body.party.code !== code) {
    return { status: 502, error: 'Room transport changed the application room' };
  }
  if (room.body.hostSession === hostId) {
    return { status: 502, error: 'Room transport used the host session as the host id' };
  }
  return openGameSession({
    applicationId,
    roomCode: room.body.party.code,
    hostId: room.body.party.hostId,
    hostSession: room.body.hostSession,
  });
}

export function guestPayload(roomCode) {
  const record = sessions.get(String(roomCode || '').toUpperCase());
  if (!record) return { status: 404, error: 'Room not found' };
  return {
    status: 200,
    payload: assertNoSecret(
      {
        ...publicSession(record),
        events: record.events.map((event) => publicEvent(record, event)),
      },
      record.hostSession,
    ),
  };
}

export function redeemInvitation(invitation, roomMember) {
  const code = invitations.get(String(invitation || ''));
  const record = code ? sessions.get(code) : null;
  if (!record || record.phase === 'closed') return { status: 404, error: 'Invitation not found' };
  if (record.memberSession) return { status: 409, error: 'Invitation already redeemed' };
  const memberId = roomMember && roomMember.memberId ? String(roomMember.memberId) : prefixedId('member');
  const memberSession = roomMember && roomMember.memberSession ? String(roomMember.memberSession) : secret();
  if (memberSession === record.hostSession || memberId === record.hostSession) {
    return { status: 403, error: 'Host session is not a member session' };
  }
  record.memberId = memberId;
  record.memberSession = memberSession;
  record.guestConnected = true;
  sessionsBySecret.set(memberSession, { roomCode: record.roomCode, role: 'guest' });
  note(record, 'logs', 'invitation_redeemed', { memberId });
  note(record, 'telemetry', 'invitation_redeemed', { memberId });
  return {
    status: 200,
    memberId,
    memberSession,
    payload: guestPayload(record.roomCode).payload,
  };
}

export function redeemInvitationOnRoom(invitation) {
  const code = invitations.get(String(invitation || ''));
  const record = code ? sessions.get(code) : null;
  if (!record || record.phase === 'closed') return { status: 404, error: 'Invitation not found' };
  if (record.memberSession) return { status: 409, error: 'Invitation already redeemed' };
  const joined = joinRoomHttp(record.roomCode);
  if (joined.status !== 200 || !joined.body?.memberSession) {
    return { status: joined.status || 403, error: joined.body?.error || 'Room join failed' };
  }
  const members = Array.isArray(joined.body.party?.members) ? joined.body.party.members : [];
  const guest = [...members].reverse().find((member) => member && member.role !== 'host');
  if (!guest?.id) return { status: 502, error: 'Room transport did not issue a member' };
  return redeemInvitation(invitation, { memberId: guest.id, memberSession: joined.body.memberSession });
}

function actor(presentedSession) {
  return sessionsBySecret.get(String(presentedSession || '')) ?? null;
}

function hostAction(presentedSession, action, phase) {
  const found = actor(presentedSession);
  if (!found || found.role !== 'host') return { status: 403, error: 'Host session required' };
  const record = sessions.get(found.roomCode);
  if (!record) return { status: 404, error: 'Room not found' };
  record.phase = phase;
  note(record, 'logs', action, { hostId: record.hostId, phase });
  note(record, 'telemetry', action, { hostId: record.hostId, phase });
  return { status: 200, session: publicSession(record) };
}

export function startGame(presentedSession) {
  return hostAction(presentedSession, 'start', 'playing');
}

export function rematchGame(presentedSession) {
  return hostAction(presentedSession, 'rematch', 'lobby');
}

export function endGame(presentedSession) {
  return hostAction(presentedSession, 'end', 'closed');
}

export function disconnectGuest(memberSession) {
  const found = actor(memberSession);
  if (!found || found.role !== 'guest') return { status: 403, error: 'Member session required' };
  const record = sessions.get(found.roomCode);
  record.guestConnected = false;
  note(record, 'logs', 'guest_disconnected', { memberId: record.memberId });
  note(record, 'telemetry', 'guest_disconnected', { memberId: record.memberId });
  return { status: 200, payload: guestPayload(record.roomCode).payload };
}

export function reconnectGuest(memberSession) {
  const found = actor(memberSession);
  if (!found || found.role !== 'guest') return { status: 403, error: 'Member session required' };
  const record = sessions.get(found.roomCode);
  if (record.phase === 'closed') return { status: 410, error: 'Room is closed' };
  record.guestConnected = true;
  note(record, 'logs', 'guest_reconnected', { memberId: record.memberId });
  note(record, 'telemetry', 'guest_reconnected', { memberId: record.memberId });
  return { status: 200, payload: guestPayload(record.roomCode).payload };
}

function raceShape(record, result) {
  if (!result || typeof result !== 'object' || Array.isArray(result)) return 'Race result is missing';
  if (JSON.stringify(result).includes(record.hostSession)) return 'Host session is not part of a race result';
  if (result.producedBy !== RACE_RUNTIME_PRODUCER) return 'Race result was not produced by the game runtime';
  if (result.applicationId !== record.applicationId || result.roomCode !== record.roomCode) {
    return 'Race result is for a different room';
  }
  if (result.hostMemberId !== record.hostId || result.guestMemberId !== record.memberId) {
    return 'Race result members do not match the room';
  }
  if (typeof result.courseId !== 'string' || result.courseId.length < 1) return 'Race result has no course';
  const laps = result.lapsCompleted;
  const checks = result.checkpointCrossings;
  if (!laps || laps.host < 1 || laps.guest < 1) return 'Both members must complete a lap';
  if (!checks || checks.host < 1 || checks.guest < 1) return 'Both members must cross a checkpoint';
  if (!Number.isInteger(result.drivenMsec) || result.drivenMsec < 1 || result.drivenMsec > DRIVE_BOUND_MSEC) {
    return 'Driven time is outside the race bound';
  }
  if (result.bothFinished !== true) return 'The race runtime did not finish both members';
  const order = Array.isArray(result.finishOrder) ? result.finishOrder : [];
  const expected = new Set([record.hostId, record.memberId]);
  if (order.length !== 2 || new Set(order).size !== 2 || order.some((id) => !expected.has(id))) {
    return 'Finish order must be the two room members';
  }
  const source = result.sourceLog;
  if (
    !source ||
    source.resultsPath !== true ||
    source.hostLapCompleted !== true ||
    source.guestLapCompleted !== true ||
    source.hostCheckpoint !== true ||
    source.guestCheckpoint !== true
  ) {
    return 'Race result is missing runtime log evidence';
  }
  return '';
}

export function submitRuntimeRaceResult(result) {
  const code = String(result?.roomCode || '').toUpperCase();
  const record = sessions.get(code);
  if (!record || !record.memberId) return { status: 404, error: 'Room members are not ready' };
  const problem = raceShape(record, result);
  if (problem) return { status: 422, error: problem };
  const digest = runtimeRaceDigest(result);
  if (result.runtimeDigest !== digest) return { status: 422, error: 'Race result digest does not match the runtime fields' };
  const stored = assertNoSecret(
    {
      applicationId: result.applicationId,
      roomCode: result.roomCode,
      courseId: result.courseId,
      hostMemberId: result.hostMemberId,
      guestMemberId: result.guestMemberId,
      lapsCompleted: { host: result.lapsCompleted.host, guest: result.lapsCompleted.guest },
      checkpointCrossings: { host: result.checkpointCrossings.host, guest: result.checkpointCrossings.guest },
      drivenMsec: result.drivenMsec,
      finishOrder: [...result.finishOrder],
      bothFinished: true,
      producedBy: result.producedBy,
      sourceLog: { ...result.sourceLog },
      runtimeDigest: digest,
    },
    record.hostSession,
  );
  record.runtimeResult = stored;
  note(record, 'logs', 'runtime_race_result', { courseId: stored.courseId, runtimeDigest: digest });
  note(record, 'telemetry', 'runtime_race_result', { courseId: stored.courseId, runtimeDigest: digest });
  return { status: 200, result: stored };
}

export function publishResult(presentedSession, packet) {
  const found = actor(presentedSession);
  if (!found || found.role !== 'host') return { status: 403, error: 'Host session required' };
  const record = sessions.get(found.roomCode);
  if (!record) return { status: 404, error: 'Room not found' };
  if (record.events.some((event) => event.type === 'result')) {
    return { status: 409, error: 'Result already published' };
  }
  const digest = packet && typeof packet.runtimeDigest === 'string' ? packet.runtimeDigest : '';
  if (!record.runtimeResult || digest !== record.runtimeResult.runtimeDigest) {
    return { status: 422, error: 'Result is not the runtime race result' };
  }
  const event = {
    type: 'result',
    eventId: prefixedId('result'),
    result: record.runtimeResult,
    choice: null,
    acknowledgements: { host: false, guest: false },
  };
  record.events.push(event);
  note(record, 'logs', 'result_published', { eventId: event.eventId, runtimeDigest: digest });
  note(record, 'telemetry', 'result_published', { eventId: event.eventId, runtimeDigest: digest });
  return { status: 200, event: publicEvent(record, event) };
}

export function publishRematchOrExit(presentedSession, choice) {
  const found = actor(presentedSession);
  if (!found || found.role !== 'host') return { status: 403, error: 'Host session required' };
  if (choice !== 'rematch' && choice !== 'exit') {
    return { status: 400, error: 'Choice must be rematch or exit' };
  }
  const record = sessions.get(found.roomCode);
  if (!record) return { status: 404, error: 'Room not found' };
  if (record.events.some((event) => event.type === 'rematch_or_exit')) {
    return { status: 409, error: 'Rematch or exit already published' };
  }
  const event = {
    type: 'rematch_or_exit',
    eventId: prefixedId('rematch-or-exit'),
    choice,
    result: null,
    acknowledgements: { host: false, guest: false },
  };
  record.events.push(event);
  note(record, 'logs', 'rematch_or_exit_published', { eventId: event.eventId, choice });
  note(record, 'telemetry', 'rematch_or_exit_published', { eventId: event.eventId, choice });
  return { status: 200, event: publicEvent(record, event) };
}

export function acknowledge(presentedSession, eventId) {
  const found = actor(presentedSession);
  if (!found) return { status: 403, error: 'Session required' };
  const record = sessions.get(found.roomCode);
  if (!record) return { status: 404, error: 'Room not found' };
  const event = record.events.find((item) => item.eventId === eventId);
  if (!event) return { status: 404, error: 'Event not found' };
  event.acknowledgements[found.role === 'host' ? 'host' : 'guest'] = true;
  note(record, 'logs', 'event_acknowledged', { eventId, role: found.role });
  note(record, 'telemetry', 'event_acknowledged', { eventId, role: found.role });
  return {
    status: 200,
    event: publicEvent(record, event),
    bothAcknowledged: event.acknowledgements.host === true && event.acknowledgements.guest === true,
  };
}

export function readLogs(roomCode) {
  const record = sessions.get(String(roomCode || '').toUpperCase());
  if (!record) return [];
  return assertNoSecret(record.logs.map((entry) => ({ ...entry })), record.hostSession);
}

export function readTelemetry(roomCode) {
  const record = sessions.get(String(roomCode || '').toUpperCase());
  if (!record) return [];
  return assertNoSecret(record.telemetry.map((entry) => ({ ...entry })), record.hostSession);
}

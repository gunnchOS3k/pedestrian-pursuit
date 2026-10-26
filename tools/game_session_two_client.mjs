/** Second client for the BeatLink room. The race result comes from the Godot file. */

import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { resetAuthority } from '../beatlink-party/apps/server/src/rooms/roomHttp.mjs';
import {
  acknowledge,
  disconnectGuest,
  endGame,
  guestPayload,
  openGameSessionOnRoom,
  publishRematchOrExit,
  publishResult,
  readLogs,
  readTelemetry,
  reconnectGuest,
  redeemInvitationOnRoom,
  rematchGame,
  resetGameSessions,
  runtimeRaceDigest,
  startGame,
  submitRuntimeRaceResult,
} from '../beatlink-party/apps/server/src/rooms/gameSessionContract.mjs';

const dir = process.env.GAME_SESSION_DIR;
const mode = process.argv[2];

function sessionPath() {
  return join(dir, 'session.json');
}

function statePath() {
  return join(dir, 'state.json');
}

function resultPath() {
  return join(dir, 'result.json');
}

function prepare() {
  resetAuthority();
  resetGameSessions();
  const opened = openGameSessionOnRoom('pedestrian-pursuit');
  if (opened.status !== 200) throw new Error(opened.error || 'session did not open');
  const redeemed = redeemInvitationOnRoom(opened.invitation);
  if (redeemed.status !== 200) throw new Error(redeemed.error || 'guest did not redeem');
  const session = {
    applicationId: opened.session.applicationId,
    roomCode: opened.session.roomCode,
    hostId: opened.session.hostId,
    memberId: redeemed.memberId,
    courseId: 'verdant_cascade_circuit',
  };
  const text = JSON.stringify(session);
  if (text.includes(opened.hostSession) || text.includes(redeemed.memberSession)) {
    throw new Error('guest session file contains a secret');
  }
  writeFileSync(sessionPath(), text);
  writeFileSync(statePath(), JSON.stringify({
    roomCode: opened.session.roomCode,
    hostSession: opened.hostSession,
    memberSession: redeemed.memberSession,
    hostId: opened.session.hostId,
    memberId: redeemed.memberId,
  }));
  console.log(`GAME_SESSION_PREPARED room=${opened.session.roomCode}`);
}

function publish() {
  const state = JSON.parse(readFileSync(statePath(), 'utf8'));
  const produced = JSON.parse(readFileSync(resultPath(), 'utf8'));
  if (produced.bothFinished !== true) {
    console.log(`GAME_SESSION_RACE_INCOMPLETE ${JSON.stringify({
      bothFinished: produced.bothFinished,
      failReason: produced.failReason || '',
      lapsCompleted: produced.lapsCompleted || null,
      checkpointCrossings: produced.checkpointCrossings || null,
      drivenMsec: produced.drivenMsec || 0,
    })}`);
    process.exit(1);
  }
  const { ecosystemReturn, failReason, ...fields } = produced;
  void ecosystemReturn;
  void failReason;
  const runtimeDigest = runtimeRaceDigest(fields);
  const stored = submitRuntimeRaceResult({ ...fields, runtimeDigest });
  if (stored.status !== 200) {
    console.log(`GAME_SESSION_RESULT_REJECTED ${stored.error}`);
    process.exit(1);
  }
  if (publishResult(state.hostSession, { label: 'shared-result' }).status !== 422) {
    throw new Error('an arbitrary host packet was accepted');
  }
  if (startGame(state.memberSession).status !== 403) throw new Error('guest start was not rejected');
  if (rematchGame(state.memberSession).status !== 403) throw new Error('guest rematch was not rejected');
  if (endGame(state.memberSession).status !== 403) throw new Error('guest end was not rejected');
  const published = publishResult(state.hostSession, { runtimeDigest });
  if (published.status !== 200) throw new Error(published.error || 'result was not published');
  acknowledge(state.hostSession, published.event.eventId);
  const guestAck = acknowledge(state.memberSession, published.event.eventId);
  if (!guestAck.bothAcknowledged) throw new Error('both clients did not acknowledge the result');
  if (disconnectGuest(state.memberSession).payload.guestConnected !== false) {
    throw new Error('guest did not disconnect');
  }
  if (reconnectGuest(state.memberSession).payload.guestConnected !== true) {
    throw new Error('guest did not reconnect');
  }
  const decision = publishRematchOrExit(state.hostSession, 'exit');
  acknowledge(state.hostSession, decision.event.eventId);
  const exitAck = acknowledge(state.memberSession, decision.event.eventId);
  if (!exitAck.bothAcknowledged || exitAck.event.choice !== 'exit') {
    throw new Error('both clients did not acknowledge exit');
  }
  if (rematchGame(state.hostSession).session.phase !== 'lobby') throw new Error('host rematch did not return to the lobby');
  if (endGame(state.hostSession).session.phase !== 'closed') throw new Error('host did not close the room');
  const visible = JSON.stringify({
    guest: guestPayload(state.roomCode).payload,
    logs: readLogs(state.roomCode),
    telemetry: readTelemetry(state.roomCode),
  });
  if (visible.includes(state.hostSession)) throw new Error('host session leaked');
  console.log(`GAME_SESSION_PUBLISHED room=${state.roomCode} course=${produced.courseId} digest=${runtimeDigest}`);
  console.log('GAME_SESSION_TWO_CLIENT_RACE=true');
  console.log('ECOSYSTEM_RETURN=ready');
  console.log('HUMAN_COURSE_APPROVAL=unset');
  console.log('HUMAN_FUN_APPROVAL=unset');
}

function run() {
  prepare();
  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const godot = spawnSync(
    'xvfb-run',
    ['-a', 'godot', '--headless', '--path', root, '--rendering-driver', 'opengl3', '--script', 'res://tests/GameSessionTwoMemberRace.gd'],
    { stdio: 'inherit' },
  );
  if (godot.status !== 0) process.exit(godot.status || 1);
  publish();
}

if (!dir) throw new Error('GAME_SESSION_DIR is required');
if (mode === 'prepare') prepare();
else if (mode === 'publish') publish();
else if (mode === 'run') run();
else throw new Error(`unknown mode ${mode}`);

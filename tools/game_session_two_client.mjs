/** Second client for the BeatLink room. The race result comes from the Godot file. */

import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Permitted cross-repo BeatLink sibling contract (do not edit BeatLink).
// Default: frozen pin under contracts/beatlink_sibling_rooms.
// Override: BEATLINK_ROOMS_ROOT -> directory containing roomHttp.mjs + gameSessionContract.mjs
// Legacy: beatlink-party/ checkout (gitignored) still accepted if present.
const __toolDir = dirname(fileURLToPath(import.meta.url));
const __repoRoot = join(__toolDir, '..');
function resolveRoomsRoot() {
  if (process.env.BEATLINK_ROOMS_ROOT) return process.env.BEATLINK_ROOMS_ROOT;
  const pin = join(__repoRoot, 'contracts', 'beatlink_sibling_rooms');
  const legacy = join(__repoRoot, 'beatlink-party', 'apps', 'server', 'src', 'rooms');
  if (existsSync(join(pin, 'roomHttp.mjs')) && existsSync(join(pin, 'gameSessionContract.mjs'))) {
    return pin;
  }
  return legacy;
}
const roomsRoot = resolveRoomsRoot();
const { resetAuthority } = await import(join(roomsRoot, 'roomHttp.mjs'));
const {
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
} = await import(join(roomsRoot, 'gameSessionContract.mjs'));

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
  mkdirSync(join(dir, 'sync'), { recursive: true });
  writeFileSync(sessionPath(), text);
  const hostView = JSON.stringify({ ...session, role: 'host' });
  const guestView = JSON.stringify({
    applicationId: session.applicationId,
    roomCode: session.roomCode,
    memberId: session.memberId,
    courseId: session.courseId,
    role: 'guest',
  });
  if (guestView.includes(opened.hostSession) || guestView.includes('hostSession')) {
    throw new Error('guest view contains the host session');
  }
  writeFileSync(join(dir, 'host_view.json'), hostView);
  writeFileSync(join(dir, 'guest_view.json'), guestView);
  writeFileSync(statePath(), JSON.stringify({
    roomCode: opened.session.roomCode,
    hostSession: opened.hostSession,
    memberSession: redeemed.memberSession,
    hostId: opened.session.hostId,
    memberId: redeemed.memberId,
    invitation: opened.invitation,
  }));
  console.log(`GAME_SESSION_PREPARED room=${opened.session.roomCode}`);
}

function publish() {
  const state = JSON.parse(readFileSync(statePath(), 'utf8'));
  const produced = JSON.parse(readFileSync(resultPath(), 'utf8'));
  const guestReport = JSON.parse(readFileSync(join(dir, 'guest_report.json'), 'utf8'));
  const guestView = readFileSync(join(dir, 'guest_view.json'), 'utf8');
  const laps = produced.lapsCompleted || {};
  const hostLaps = Number(laps.host || 0);
  const guestLaps = Number(laps.guest || 0);
  const expectedLaps = Number(produced.expectedLaps || 0);
  const lapsEqual = hostLaps === guestLaps && produced.lapsEqual !== false;
  const lapsComplete = expectedLaps > 0
    ? (hostLaps === expectedLaps && guestLaps === expectedLaps)
    : (hostLaps > 0 && guestLaps > 0 && lapsEqual);
  const bothHumansFinished = produced.hostFinished === true && produced.guestFinished === true;
  // Reject false-green: results with disagreeing lap counts (e.g. host 2 / guest 3).
  const independent = (
    produced.bothFinished === true
    && bothHumansFinished
    && lapsEqual
    && lapsComplete
    && produced.courseAiIsGuest === false
    && produced.guestSeat === 'Player2Racer'
    && produced.guestControl === 'guest-process'
    && produced.hostControl === 'host-process'
    && guestReport.source === 'guest-process'
    && guestReport.containsHostSession === false
    && guestReport.courseAiIsGuest === false
    && Number(guestReport.pid) !== Number(produced.hostPid)
    && Number(guestReport.inputFrames) > 30
    && !guestView.includes(state.hostSession)
  );
  if (!independent) {
    console.log(`INDEPENDENT_CLIENTS_RACED=false ${JSON.stringify({
      bothFinished: produced.bothFinished,
      failReason: produced.failReason || (
        !lapsEqual
          ? `lap counts disagree host=${hostLaps} guest=${guestLaps} expected=${expectedLaps}`
          : (!lapsComplete ? `finished laps incomplete host=${hostLaps} guest=${guestLaps} expected=${expectedLaps}` : '')
      ),
      guestSeat: produced.guestSeat || '',
      guestControl: produced.guestControl || '',
      courseAiIsGuest: produced.courseAiIsGuest,
      expectedLaps,
      lapsCompleted: produced.lapsCompleted || null,
      lapsEqual,
      hostFinished: produced.hostFinished || false,
      guestFinished: produced.guestFinished || false,
      checkpointCrossings: produced.checkpointCrossings || null,
      drivenMsec: produced.drivenMsec || 0,
      guestCommands: produced.guestCommands || 0,
    })}`);
    process.exit(1);
  }
  const fields = {
    applicationId: produced.applicationId,
    roomCode: produced.roomCode,
    courseId: produced.courseId,
    hostMemberId: produced.hostMemberId,
    guestMemberId: produced.guestMemberId,
    lapsCompleted: produced.lapsCompleted,
    checkpointCrossings: produced.checkpointCrossings,
    drivenMsec: produced.drivenMsec,
    finishOrder: produced.finishOrder,
    bothFinished: produced.bothFinished,
    producedBy: produced.producedBy,
    sourceLog: produced.sourceLog,
  };
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
  const again = redeemInvitationOnRoom(state.invitation);
  if (again.status !== 409) throw new Error('a second redeem created a duplicate member');
  const restored = reconnectGuest(state.memberSession);
  if (restored.status !== 200 || restored.payload.guestConnected !== true) {
    throw new Error('guest did not reconnect');
  }
  if (restored.payload.memberId !== state.memberId) {
    throw new Error('reconnect duplicated the member');
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
  console.log('INDEPENDENT_CLIENTS_RACED=true');
  console.log('ECOSYSTEM_RETURN=ready');
  console.log('HUMAN_COURSE_APPROVAL=unset');
  console.log('HUMAN_FUN_APPROVAL=unset');
}

function startGodot(root, script) {
  // Prefer explicit headless display. On Darwin, CI-style xvfb is unavailable;
  // tools/bin/xvfb-run (local shim) or PATH xvfb-run on Ubuntu both work.
  // Keep opengl3 so macOS does not take the Metal/MoltenVK crash path.
  // PATH must include tools/bin (see tools/run_game_session_race.sh).
  const args = [
    '--headless',
    '--display-driver', 'headless',
    '--rendering-driver', 'opengl3',
    '--path', root,
    '--script', script,
  ];
  const env = { ...process.env };
  const shimBin = join(root, 'tools', 'bin');
  env.PATH = `${shimBin}${env.PATH ? `:${env.PATH}` : ''}`;
  const xvfb = join(shimBin, 'xvfb-run');
  if (existsSync(xvfb)) {
    return spawn(xvfb, ['-a', 'godot', ...args], { stdio: 'inherit', env });
  }
  // Darwin without shim: headless display-driver already set; spawn godot directly.
  return spawn('godot', args, { stdio: 'inherit', env });
}

function waitFor(child) {
  return new Promise((resolve) => {
    child.on('exit', (code) => resolve(code ?? 1));
  });
}

async function run() {
  prepare();
  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const guest = startGodot(root, 'res://tests/GameSessionGuestInput.gd');
  const host = startGodot(root, 'res://tests/GameSessionHostRace.gd');
  const finished = Promise.all([waitFor(guest), waitFor(host)]);
  const outcome = await Promise.race([
    finished.then((codes) => ({ codes })),
    new Promise((resolve) => setTimeout(() => resolve('timeout'), 240000)),
  ]);
  if (outcome === 'timeout') {
    guest.kill('SIGKILL');
    host.kill('SIGKILL');
    console.log('INDEPENDENT_CLIENTS_RACED=false reason=two-process-timeout');
    process.exit(1);
  }
  const [guestCode, hostCode] = outcome.codes;
  if (guestCode !== 0 || hostCode !== 0) {
    console.log(`INDEPENDENT_CLIENTS_RACED=false host_exit=${hostCode} guest_exit=${guestCode}`);
    process.exit(guestCode || hostCode || 1);
  }
  publish();
}

if (!dir) throw new Error('GAME_SESSION_DIR is required');
if (mode === 'prepare') prepare();
else if (mode === 'publish') publish();
else if (mode === 'run') {
  run().catch((error) => {
    console.error(error);
    console.log('INDEPENDENT_CLIENTS_RACED=false');
    process.exit(1);
  });
} else throw new Error(`unknown mode ${mode}`);

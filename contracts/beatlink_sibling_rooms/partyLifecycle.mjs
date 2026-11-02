/** Plain room membership. No sockets and no network listen. */

export function createParty({ code, hostId }) {
  if (!code || !hostId) throw new Error('A room needs a code and a host');
  return {
    code: String(code).toUpperCase(),
    phase: 'lobby',
    hostId,
    members: [{ id: hostId, role: 'host', connected: true }],
  };
}

export function addMember(party, memberId) {
  if (!party || party.phase === 'closed' || !memberId) return null;
  if (memberId === party.hostId || party.members.some((member) => member.id === memberId)) return party;
  return {
    ...party,
    members: [...party.members, { id: memberId, role: 'member', connected: true }],
  };
}

export function disconnectMember(party, memberId) {
  if (!party) return null;
  if (party.phase === 'closed' || !memberId || memberId === party.hostId) return party;
  return {
    ...party,
    members: party.members.filter((member) => member.id !== memberId),
  };
}

export function endParty(party, hostId) {
  if (!party || hostId !== party.hostId) return null;
  return { ...party, phase: 'closed', members: [] };
}

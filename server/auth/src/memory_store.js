// Stockage en mémoire : tests et développement local.

import { randomUUID } from 'node:crypto';

export function createMemoryStore(initialRows = []) {
  const rows = initialRows.map((row) => ({ ...row }));
  return {
    rows,
    passwordHashOf: (row) => row.mdp ?? '',
    async findByEmail(email) {
      return rows.find((row) => String(row.email).trim().toLowerCase() === email) ?? null;
    },
    async findByPseudo(pseudo) {
      return rows.find((row) => String(row.pseudo ?? '').trim().toLowerCase() === pseudo) ?? null;
    },
    async createUser({ passwordHash, ...fields }) {
      const row = { user_id: randomUUID(), ...fields, mdp: passwordHash };
      rows.push(row);
      return row;
    },
    async updatePasswordHash(row, passwordHash) {
      row.mdp = passwordHash;
    },
  };
}

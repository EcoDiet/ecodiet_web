// Stockage BigQuery de la table des utilisateurs (dim_utilisateur).
// Requêtes paramétrées ; noms de table et de colonnes validés.

import { randomInt, randomUUID } from 'node:crypto';

const IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;
const TABLE = /^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+){1,2}$/;

/**
 * @param {object} options
 * @param {import('@google-cloud/bigquery').BigQuery} options.bigquery
 * @param {string} options.table `projet.dataset.table` ou `dataset.table`
 * @param {string} [options.passwordColumn] colonne du hachage (défaut `mdp`)
 * @param {string} [options.idColumn] identifiant (défaut `user_id`)
 * @param {'string'|'int'} [options.idType] type de l'identifiant
 * @param {string} [options.location] région BigQuery (ex. `EU`)
 * @param {string} [options.stateTable] table des données du compte
 *   (sql/user_state.sql) ; sans elle, /me/state répond 501
 */
export function createBigQueryStore({
  bigquery,
  table,
  passwordColumn = 'mdp',
  idColumn = 'user_id',
  idType = 'string',
  location,
  stateTable,
}) {
  if (stateTable && !TABLE.test(stateTable)) {
    throw new Error(`Nom de table invalide : ${stateTable}`);
  }
  if (!TABLE.test(table)) throw new Error(`Nom de table invalide : ${table}`);
  for (const column of [passwordColumn, idColumn]) {
    if (!IDENTIFIER.test(column)) throw new Error(`Nom de colonne invalide : ${column}`);
  }
  const ref = `\`${table}\``;

  async function run(query, params) {
    const [rows] = await bigquery.query({ query, params, location });
    return rows;
  }

  const newId = () =>
    idType === 'int' ? Date.now() * 1000 + randomInt(1000) : randomUUID();

  const stateRef = stateTable ? `\`${stateTable}\`` : null;

  const stateMethods = stateRef
    ? {
        async getState(email) {
          const rows = await run(
            `SELECT state, updated_at FROM ${stateRef} WHERE email = @email LIMIT 1`,
            { email },
          );
          if (!rows[0]) return null;
          const updatedAt = rows[0].updated_at?.value ?? rows[0].updated_at;
          return { state: JSON.parse(rows[0].state), updated_at: String(updatedAt) };
        },
        async saveState(email, text, updatedAt) {
          await run(
            `MERGE ${stateRef} T USING (SELECT @email AS email) S ON T.email = S.email
             WHEN MATCHED THEN UPDATE SET state = @state, updated_at = TIMESTAMP(@updatedAt)
             WHEN NOT MATCHED THEN INSERT (email, state, updated_at)
               VALUES (@email, @state, TIMESTAMP(@updatedAt))`,
            { email, state: text, updatedAt },
          );
        },
      }
    : {};

  return {
    ...stateMethods,
    passwordHashOf: (row) => String(row[passwordColumn] ?? ''),

    async findByEmail(email) {
      const rows = await run(
        `SELECT * FROM ${ref} WHERE LOWER(TRIM(email)) = @email LIMIT 1`,
        { email },
      );
      return rows[0] ?? null;
    },

    async findByPseudo(pseudo) {
      const rows = await run(
        `SELECT email FROM ${ref} WHERE LOWER(TRIM(pseudo)) = @pseudo LIMIT 1`,
        { pseudo },
      );
      return rows[0] ?? null;
    },

    async createUser({ passwordHash, ...fields }) {
      const row = { ...fields, [idColumn]: newId(), [passwordColumn]: passwordHash };
      const columns = Object.keys(row).filter((column) => IDENTIFIER.test(column));
      await run(
        `INSERT INTO ${ref} (${columns.join(', ')}) VALUES (${columns
          .map((column) => `@${column}`)
          .join(', ')})`,
        Object.fromEntries(columns.map((column) => [column, row[column]])),
      );
      return row;
    },

    async updatePasswordHash(row, passwordHash) {
      await run(
        `UPDATE ${ref} SET ${passwordColumn} = @hash WHERE LOWER(TRIM(email)) = @email`,
        { hash: passwordHash, email: String(row.email).trim().toLowerCase() },
      );
    },
  };
}

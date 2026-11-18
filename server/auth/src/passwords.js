// Hachage des mots de passe : scrypt salé (module crypto de Node, aucune
// dépendance). Format stocké : scrypt$N$r$p$sel_base64$cle_base64.
//
// Les anciens comptes ont un SHA-256 (voire MD5 / SHA-1) sans sel du mot de
// passe : ils sont acceptés une dernière fois puis re-hachés en scrypt.

import { createHash, randomBytes, scrypt, timingSafeEqual } from 'node:crypto';

const PARAMS = { N: 2 ** 15, r: 8, p: 1 };
const KEY_LENGTH = 32;
const SALT_LENGTH = 16;

function derive(password, salt, { N, r, p }) {
  return new Promise((resolve, reject) => {
    scrypt(
      password.normalize('NFC'),
      salt,
      KEY_LENGTH,
      // maxmem doit couvrir 128 * N * r octets.
      { N, r, p, maxmem: 256 * N * r },
      (error, key) => (error ? reject(error) : resolve(key)),
    );
  });
}

export async function hashPassword(password) {
  const salt = randomBytes(SALT_LENGTH);
  const key = await derive(password, salt, PARAMS);
  const { N, r, p } = PARAMS;
  return `scrypt$${N}$${r}$${p}$${salt.toString('base64')}$${key.toString('base64')}`;
}

function safeEqual(a, b) {
  return a.length === b.length && timingSafeEqual(a, b);
}

function legacyMatches(password, stored) {
  // L'ancienne app hachait le mot de passe après trim().
  const plain = password.trim();
  const expected = Buffer.from(stored.trim().toLowerCase());
  return ['sha256', 'md5', 'sha1'].some((algorithm) =>
    safeEqual(Buffer.from(createHash(algorithm).update(plain).digest('hex')), expected),
  );
}

/**
 * Vérifie un mot de passe.
 * @returns {Promise<{ok: boolean, needsRehash: boolean}>} `needsRehash` est
 *   vrai pour un ancien hachage ou des paramètres scrypt dépassés.
 */
export async function verifyPassword(password, stored) {
  if (typeof password !== 'string' || typeof stored !== 'string' || !stored) {
    return { ok: false, needsRehash: false };
  }
  if (!stored.startsWith('scrypt$')) {
    const ok = legacyMatches(password, stored);
    return { ok, needsRehash: ok };
  }
  const parts = stored.split('$');
  if (parts.length !== 6) return { ok: false, needsRehash: false };
  const [, n, r, p, saltB64, keyB64] = parts;
  const params = { N: Number(n), r: Number(r), p: Number(p) };
  if (![params.N, params.r, params.p].every(Number.isInteger)) {
    return { ok: false, needsRehash: false };
  }
  const key = await derive(password, Buffer.from(saltB64, 'base64'), params);
  const ok = safeEqual(key, Buffer.from(keyB64, 'base64'));
  const outdated =
    params.N !== PARAMS.N || params.r !== PARAMS.r || params.p !== PARAMS.p;
  return { ok, needsRehash: ok && outdated };
}

/** Calcul factice pour qu'un e-mail inconnu prenne autant de temps. */
export async function burnTime(password) {
  await derive(String(password ?? ''), randomBytes(SALT_LENGTH), PARAMS);
}

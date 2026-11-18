import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import { hashPassword, verifyPassword } from '../src/passwords.js';

const hex = (algorithm, text) => createHash(algorithm).update(text).digest('hex');

test('scrypt : salé, vérifiable, refuse un autre mot de passe', async () => {
  const a = await hashPassword('mot de passe sûr');
  const b = await hashPassword('mot de passe sûr');
  assert.match(a, /^scrypt\$32768\$8\$1\$/);
  assert.notEqual(a, b, 'deux hachages du même mot de passe diffèrent (sel)');
  assert.deepEqual(await verifyPassword('mot de passe sûr', a), { ok: true, needsRehash: false });
  assert.deepEqual(await verifyPassword('autre', a), { ok: false, needsRehash: false });
});

test('anciens hachages sans sel acceptés puis à re-hacher', async () => {
  for (const algorithm of ['sha256', 'md5', 'sha1']) {
    const stored = hex(algorithm, 'secret123');
    assert.deepEqual(await verifyPassword('secret123', stored), { ok: true, needsRehash: true });
    assert.deepEqual(await verifyPassword('secret124', stored), { ok: false, needsRehash: false });
  }
  // L'ancienne app hachait après trim() ; majuscules tolérées.
  const upper = hex('sha256', 'secret123').toUpperCase();
  assert.equal((await verifyPassword('  secret123 ', upper)).ok, true);
});

test('paramètres scrypt modifiés : clé refusée', async () => {
  const current = await hashPassword('abc12345');
  const [, , , , salt, key] = current.split('$');
  const weaker = `scrypt$16384$8$1$${salt}$${key}`;
  // La clé ne correspond pas aux paramètres affaiblis : refus.
  assert.equal((await verifyPassword('abc12345', weaker)).ok, false);
});

test('valeurs absentes ou mal formées refusées', async () => {
  for (const stored of ['', 'scrypt$x', 'scrypt$a$b$c$d$e', null]) {
    assert.equal((await verifyPassword('abc', stored)).ok, false);
  }
});

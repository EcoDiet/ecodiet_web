import assert from 'node:assert/strict';
import test from 'node:test';

import { createToken, verifyToken } from '../src/tokens.js';

const secret = 'x'.repeat(32);
const t0 = Date.UTC(2026, 0, 1);

test('jeton valide jusqu à expiration', () => {
  const token = createToken({ sub: '42', email: 'a@b.fr' }, { secret, ttlSeconds: 60, now: t0 });
  assert.equal(verifyToken(token, { secret, now: t0 + 30_000 }).sub, '42');
  assert.equal(verifyToken(token, { secret, now: t0 + 61_000 }), null);
});

test('signature, secret ou contenu modifiés : refusé', () => {
  const token = createToken({ sub: '42', email: 'a@b.fr' }, { secret, ttlSeconds: 60, now: t0 });
  const [h, p, s] = token.split('.');
  const forged = Buffer.from(JSON.stringify({ sub: '1', email: 'x@y.fr', exp: 9e9 })).toString('base64url');
  assert.equal(verifyToken(`${h}.${forged}.${s}`, { secret, now: t0 }), null);
  assert.equal(verifyToken(token, { secret: 'y'.repeat(32), now: t0 }), null);
  assert.equal(verifyToken(`${h}.${p}.`, { secret, now: t0 }), null);
  assert.equal(verifyToken('abc', { secret, now: t0 }), null);
});

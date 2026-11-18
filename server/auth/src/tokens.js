// Jeton de session : JWT HS256 (en-tête.charge.signature, base64url), signé
// avec le secret du service. Aucune dépendance.

import { createHmac, timingSafeEqual } from 'node:crypto';

const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const HEADER = encode({ alg: 'HS256', typ: 'JWT' });

function sign(data, secret) {
  return createHmac('sha256', secret).update(data).digest('base64url');
}

/**
 * @param {{sub: string, email: string}} claims
 * @param {{secret: string, ttlSeconds: number, now?: number}} options
 */
export function createToken(claims, { secret, ttlSeconds, now = Date.now() }) {
  const iat = Math.floor(now / 1000);
  const payload = encode({ ...claims, iat, exp: iat + ttlSeconds });
  const data = `${HEADER}.${payload}`;
  return `${data}.${sign(data, secret)}`;
}

/** Charge du jeton s'il est intact et non expiré, sinon `null`. */
export function verifyToken(token, { secret, now = Date.now() }) {
  if (typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== HEADER) return null;
  const expected = Buffer.from(sign(`${parts[0]}.${parts[1]}`, secret));
  const actual = Buffer.from(parts[2]);
  if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) {
    return null;
  }
  try {
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString());
    if (typeof payload.exp !== 'number' || payload.exp * 1000 <= now) return null;
    return payload;
  } catch {
    return null;
  }
}

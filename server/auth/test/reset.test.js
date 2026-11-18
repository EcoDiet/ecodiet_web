import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createAuthHandler } from '../src/handler.js';
import { createResendMailer } from '../src/mailers.js';
import { createMemoryStore } from '../src/memory_store.js';

const secret = 'r'.repeat(40);

async function start(options) {
  const handle = createAuthHandler({ store: createMemoryStore(), secret, ...options });
  const server = http.createServer(async (req, res) => {
    if (!(await handle(req, res))) res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (path, body, headers = {}) => {
    const response = await fetch(base + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { 'Content-Type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
  return {
    call,
    close: () => new Promise((resolve) => {
      server.close(resolve);
      server.closeAllConnections();
    }),
  };
}

const account = { email: 'ana@exemple.fr', password: 'ancien-mot-de-passe', nom: 'L', prenom: 'Ana', pseudo: 'ana' };

function capture() {
  const sent = [];
  return { sent, mailer: { send: async (mail) => sent.push(mail) } };
}
const tokenOf = (mail) => mail.text.match(/token=([\w.-]+)/)[1];

test('demande puis confirmation : nouveau mot de passe, lien à usage unique', async (t) => {
  const { sent, mailer } = capture();
  const api = await start({ mailer, resetUrl: 'https://app.example/#/reset_password' });
  t.after(api.close);
  await api.call('/auth/register', account);

  assert.deepEqual((await api.call('/auth/password-reset/request', { email: ' ANA@exemple.fr' })).body, { ok: true });
  assert.equal(sent.length, 1);
  assert.equal(sent[0].to, 'ana@exemple.fr');
  assert.match(sent[0].text, /https:\/\/app\.example\/#\/reset_password\?token=/);
  const token = tokenOf(sent[0]);

  // Un jeton de réinitialisation n'ouvre pas de session.
  assert.equal((await api.call('/auth/me', undefined, { Authorization: `Bearer ${token}` })).status, 401);

  assert.equal((await api.call('/auth/password-reset/confirm', { token, password: 'court' })).status, 400);
  assert.equal((await api.call('/auth/password-reset/confirm', { token, password: 'nouveau-mot-de-passe' })).status, 200);
  assert.equal((await api.call('/auth/password-reset/confirm', { token, password: 'encore-un-autre' })).status, 400, 'usage unique');

  assert.equal((await api.call('/auth/login', { email: account.email, password: account.password })).status, 401);
  assert.equal((await api.call('/auth/login', { email: account.email, password: 'nouveau-mot-de-passe' })).status, 200);
});

test('e-mail inconnu : même réponse, aucun envoi ; jeton de session refusé', async (t) => {
  const { sent, mailer } = capture();
  const api = await start({ mailer, resetUrl: 'https://app.example/reset' });
  t.after(api.close);
  const session = (await api.call('/auth/register', account)).body.token;

  assert.deepEqual((await api.call('/auth/password-reset/request', { email: 'inconnu@exemple.fr' })).body, { ok: true });
  assert.equal(sent.length, 0);
  assert.equal((await api.call('/auth/password-reset/confirm', { token: session, password: 'nouveau-mot-de-passe' })).status, 400);
});

test('au plus 3 e-mails par heure et par adresse', async (t) => {
  const { sent, mailer } = capture();
  const api = await start({ mailer, resetUrl: 'https://app.example/reset' });
  t.after(api.close);
  await api.call('/auth/register', account);
  for (let i = 0; i < 5; i++) {
    assert.equal((await api.call('/auth/password-reset/request', { email: account.email })).status, 200);
  }
  assert.equal(sent.length, 3);
});

test('sans service d e-mail : 503', async (t) => {
  const api = await start({});
  t.after(api.close);
  assert.equal((await api.call('/auth/password-reset/request', { email: account.email })).status, 503);
});

test('Resend : requête HTTP attendue, erreur levée si refus', async () => {
  const calls = [];
  const mailer = createResendMailer({
    apiKey: 'cle',
    from: 'EcoDiet <noreply@exemple.fr>',
    fetchImpl: async (url, init) => {
      calls.push({ url, init });
      return { ok: calls.length === 1, status: 422 };
    },
  });
  await mailer.send({ to: 'a@b.fr', subject: 'Objet', text: 'Corps' });
  assert.equal(calls[0].url, 'https://api.resend.com/emails');
  assert.equal(calls[0].init.headers.Authorization, 'Bearer cle');
  assert.deepEqual(JSON.parse(calls[0].init.body).to, ['a@b.fr']);
  await assert.rejects(mailer.send({ to: 'a@b.fr', subject: 'x', text: 'y' }), /422/);
});

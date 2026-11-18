// Envoi des e-mails (réinitialisation du mot de passe).
// Interface : `{ send({ to, subject, text }) => Promise<void> }`.

/** Développement : affiche l'e-mail dans la console au lieu de l'envoyer. */
export function createConsoleMailer(log = console.log) {
  return {
    async send({ to, subject, text }) {
      log(`[e-mail] à ${to} — ${subject}\n${text}`);
    },
  };
}

/** Envoi via l'API HTTP de Resend (https://resend.com). */
export function createResendMailer({ apiKey, from, fetchImpl = fetch }) {
  if (!apiKey || !from) throw new Error('RESEND_API_KEY et MAIL_FROM sont requis.');
  return {
    async send({ to, subject, text }) {
      const response = await fetchImpl('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from, to: [to], subject, text }),
      });
      if (!response.ok) {
        throw new Error(`Resend HTTP ${response.status}`);
      }
    },
  };
}

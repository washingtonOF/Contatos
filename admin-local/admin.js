'use strict';
// Run ONLY on a trusted computer using Application Default Credentials.
// Never commit a service-account key or share it with the Web app.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const readline = require('node:readline/promises');
const { stdin, stdout } = require('node:process');
initializeApp({ credential: applicationDefault(), projectId: 'contatos-6c266' });
const auth = getAuth();
const [action, ...args] = process.argv.slice(2);
async function main() {
  if (action === 'create') {
    const [email, name] = args;
    if (!email || !name || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw Error('Uso: create email nome');
    const rl = readline.createInterface({ input: stdin, output: stdout });
    let password;
    try { password = await rl.question('Senha temporária (12+ caracteres; entrada visível): '); }
    finally { rl.close(); }
    if (password.length < 12) throw Error('Senha muito curta');
    const user = await auth.createUser({ email, displayName: name, password, emailVerified: false });
    await auth.setCustomUserClaims(user.uid, { managed: true });
    stdout.write('Conta criada: ' + user.uid + '\n');
    return;
  }
  if (action === 'list') {
    let token;
    do {
      const page = await auth.listUsers(100, token);
      for (const u of page.users) stdout.write(JSON.stringify({
        uid: u.uid, email: u.email, name: u.displayName, disabled: u.disabled,
        verified: u.emailVerified, managed: u.customClaims?.managed === true
      }) + '\n');
      token = page.pageToken;
    } while (token);
    return;
  }
  if (action === 'disable' || action === 'enable') {
    const uid = args[0];
    if (!uid) throw Error('Informe o UID');
    const u = await auth.getUser(uid);
    if (u.customClaims?.admin === true) throw Error('Operação proibida para administradores');
    await auth.updateUser(uid, { disabled: action === 'disable' });
    await auth.revokeRefreshTokens(uid);
    stdout.write('Conta atualizada\n');
    return;
  }
  if (action === 'grant-admin') {
    const uid = args[0];
    if (!uid) throw Error('Informe o UID de uma conta previamente verificada');
    const u = await auth.getUser(uid);
    if (!u.emailVerified) throw Error('Verifique a titularidade do administrador antes de conceder acesso. E-mail não verificado.');
    await auth.setCustomUserClaims(uid, { ...(u.customClaims || {}), admin: true });
    stdout.write('Permissão administrativa concedida. Faça novo login.\n');
    return;
  }
  throw Error('Comandos: create <email> <nome> | list | disable <uid> | enable <uid> | grant-admin <uid>');
}
main().catch(e => { process.stderr.write(e.message + '\n'); process.exitCode = 1; });

"use strict";
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
initializeApp();

const region = "southamerica-east1";
const options = { region, enforceAppCheck: true, maxInstances: 5, invoker: "public" };
function requireAdmin(request) {
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Acesso restrito ao administrador.");
  }
}
function validEmail(email) {
  return typeof email === "string" && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) && email.length <= 254;
}
exports.createManagedUser = onCall(options, async (request) => {
  requireAdmin(request);
  const { name, email, password } = request.data || {};
  if (typeof name !== "string" || name.trim().length < 2 || name.length > 80 ||
      !validEmail(email) || typeof password !== "string" || password.length < 12 || password.length > 128) {
    throw new HttpsError("invalid-argument", "Informe nome, e-mail válido e senha com 12 a 128 caracteres.");
  }
  try {
    const user = await getAuth().createUser({
      displayName: name.trim(),
      email: email.trim().toLowerCase(),
      password,
      emailVerified: false,
      disabled: false,
    });
    // Admin-created accounts are usable immediately; no false email verification claim.
    return { uid: user.uid };
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "E-mail já cadastrado.");
    }
    throw new HttpsError("internal", "Não foi possível criar a conta.");
  }
});
exports.setManagedUserDisabled = onCall(options, async (request) => {
  requireAdmin(request);
  const { uid, disabled } = request.data || {};
  if (typeof uid !== "string" || !uid || typeof disabled !== "boolean" || uid === request.auth.uid) {
    throw new HttpsError("invalid-argument", "Dados inválidos ou tentativa de bloquear a própria conta.");
  }
  const target = await getAuth().getUser(uid);
  if (target.customClaims?.admin === true) {
    throw new HttpsError("permission-denied", "Não é permitido bloquear administradores.");
  }
  await getAuth().updateUser(uid, { disabled });
  await getAuth().revokeRefreshTokens(uid);
  return { success: true };
});
exports.listManagedUsers = onCall(options, async (request) => {
  requireAdmin(request);
  const pageSize = 50;
  const token = request.data?.pageToken;
  if (token != null && (typeof token !== "string" || token.length > 2048)) {
    throw new HttpsError("invalid-argument", "Página inválida.");
  }
  const page = await getAuth().listUsers(pageSize, token || undefined);
  return {
    users: page.users.map(u => ({
      uid: u.uid, name: u.displayName || "", email: u.email || "",
      disabled: u.disabled, verified: u.emailVerified,
      createdAt: u.metadata.creationTime,
    })),
    nextPageToken: page.pageToken || null,
  };
});

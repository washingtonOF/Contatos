"use strict";
const {onCall,HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore,FieldValue} = require("firebase-admin/firestore");
initializeApp();
async function requireAdmin(request) {
  if (!request.auth || request.auth.token.admin !== true || request.auth.token.email_verified !== true) {
    throw new HttpsError("permission-denied","Acesso exclusivo a administradores verificados.");
  }
  const actor = await getAuth().getUser(request.auth.uid);
  if (actor.disabled || !actor.emailVerified || actor.customClaims?.admin !== true) {
    throw new HttpsError("permission-denied","Permissão administrativa não está ativa.");
  }
  return actor;
}
exports.listManagedUsers = onCall({region:"southamerica-east1",enforceAppCheck:false,maxInstances:5}, async (request) => {
  await requireAdmin(request);
  const pageToken = request.data?.pageToken;
  if (pageToken !== undefined && (typeof pageToken !== "string" || pageToken.length > 2048)) {
    throw new HttpsError("invalid-argument","Página inválida.");
  }
  const result = await getAuth().listUsers(50,pageToken || undefined);
  return {users:result.users.map(u=>({
    uid:u.uid, email:u.email || "",name:u.displayName || "",disabled:u.disabled,
    verified:u.emailVerified,createdAt:u.metadata.creationTime || null,
    lastSignInAt:u.metadata.lastSignInTime || null,
    admin:u.customClaims?.admin === true
  })),nextPageToken:result.pageToken || null};
});
exports.setManagedUserDisabled = onCall({region:"southamerica-east1",enforceAppCheck:false,maxInstances:5}, async(request)=>{
  const actor=await requireAdmin(request);
  const {uid,disabled}=request.data || {};
  if(typeof uid!=="string" || uid.length>128 || !uid || typeof disabled!=="boolean"){
    throw new HttpsError("invalid-argument","Dados inválidos.");
  }
  if(uid===actor.uid) throw new HttpsError("failed-precondition","Não é possível bloquear sua própria conta.");
  const target=await getAuth().getUser(uid);
  if(target.customClaims?.admin===true) throw new HttpsError("failed-precondition","Contas administrativas não podem ser alteradas neste painel.");
  await getAuth().updateUser(uid,{disabled});
  await getFirestore().collection("admin_audit").add({
    actorUid:actor.uid,targetUid:uid,action:disabled?"disable_user":"enable_user",
    createdAt:FieldValue.serverTimestamp()
  });
  return {success:true};
});

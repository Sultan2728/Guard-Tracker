/**
 * Опциональная Cloud Function: отправляет push-уведомление начальнику,
 * когда охранник входит в зону или выходит из неё.
 *
 * Установка (см. README.md, раздел "Push-уведомления"):
 *   cd functions
 *   npm install firebase-admin firebase-functions
 *   firebase deploy --only functions
 *
 * Требует план Firebase Blaze (pay-as-you-go). При таком малом объёме
 * вызовов (несколько в день на охранника) стоимость практически нулевая
 * и укладывается в бесплатный лимит Blaze-плана.
 */

const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

const TYPE_LABELS = {
  enter: 'вошёл в зону объекта',
  exit: 'вышел из зоны объекта',
};

exports.notifyBossOnZoneChange = onDocumentWritten('status/{guardDoc}', async (event) => {
  const before = event.data.before.exists ? event.data.before.data() : null;
  const after = event.data.after.exists ? event.data.after.data() : null;
  if (!after) return;

  // Fire only on an actual in/out transition, not every GPS ping.
  if (before && before.inZone === after.inZone) return;

  const slot = after.slot;
  const label = after.inZone ? TYPE_LABELS.enter : TYPE_LABELS.exit;

  const tokenDoc = await admin.firestore().collection('tokens').doc('boss').get();
  const token = tokenDoc.exists ? tokenDoc.data().fcmToken : null;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: {
      title: `Охранник ${slot}`,
      body: `Охранник ${slot} ${label}`,
    },
    data: { slot: String(slot), inZone: String(after.inZone) },
  });
});

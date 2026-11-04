/**
 * Cloud Function: push-уведомление начальнику, когда работник входит в зону
 * объекта, выходит из неё, начинает или заканчивает смену. Работает, даже
 * когда приложение начальника закрыто.
 *
 * Установка: см. README.md, раздел "Push-уведомления".
 *   cd functions && npm install && firebase deploy --only functions
 *
 * Требует план Firebase Blaze. При малом объёме вызовов стоимость
 * практически нулевая (укладывается в бесплатный лимит).
 */

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
admin.initializeApp();

const LABELS = {
  enter: 'вошёл(а) в зону объекта',
  exit: 'вышел(а) из зоны объекта',
  shift_start: 'начал(а) смену',
  shift_end: 'закончил(а) смену',
};

exports.notifyBossOnEvent = onDocumentCreated('events/{eventId}', async (event) => {
  const e = event.data && event.data.data();
  if (!e || !LABELS[e.type]) return;

  const db = admin.firestore();
  let siteName = '';
  if (e.siteId) {
    const site = await db.collection('sites').doc(e.siteId).get();
    siteName = site.exists ? site.data().name || '' : '';
  }

  const snap = await db.collection('tokens').where('isBoss', '==', true).get();
  const tokens = snap.docs.map((d) => d.data().fcmToken).filter(Boolean);
  if (tokens.length === 0) return;

  const who = `${e.workerName || 'Сотрудник'}${e.role ? ` (${e.role})` : ''}`;
  const body = `${LABELS[e.type]}${siteName ? ` «${siteName}»` : ''}`;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: who, body },
    // Same tag as the in-app local alert, so one event shows only once.
    android: { notification: { channelId: 'zone_events', tag: event.params.eventId } },
    data: { type: String(e.type), siteId: String(e.siteId || '') },
  });

  // Clean up tokens of phones that uninstalled the app.
  const dead = [];
  res.responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (code === 'messaging/registration-token-not-registered' || code === 'messaging/invalid-registration-token') {
      dead.push(snap.docs[i].ref.delete());
    }
  });
  await Promise.all(dead);
});

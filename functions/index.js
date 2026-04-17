const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');
admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// 1. PUSH NOTIFICATION — dispara quando cria notif no Firestore
// ─────────────────────────────────────────────────────────────────────────────
exports.sendNotification = functions.firestore
  .document('users/{uid}/notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const uid  = context.params.uid;
    const data = snap.data();

    const user  = await admin.firestore().doc(`users/${uid}`).get();
    const token = user.data()?.fcmToken;
    if (!token) return null;

    return admin.messaging().send({
      token,
      notification: { title: data.title, body: data.body },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// 2. EMAIL DIÁRIO — 9h, só quem não jogou hoje
// ─────────────────────────────────────────────────────────────────────────────
exports.emailDiario = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today    = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch    = admin.firestore().batch();

    for (const doc of usersSnap.docs) {
      const data  = doc.data();
      const email = data.email;
      const name  = data.nickname || data.name || 'Jogador';
      if (!email) continue;

      // Só envia se não fez quizzes hoje
      const missSnap = await admin.firestore()
        .collection('users').doc(doc.id)
        .collection('daily_missions').doc(today).get();
      const quizzes = missSnap.exists ? (missSnap.data().quizzesDone || 0) : 0;
      if (quizzes > 0) continue;

      const ref = admin.firestore().collection('mail').doc();
      batch.set(ref, {
        to: email,
        message: {
          subject: `📋 ${name}, as tuas missões SafeQuest esperam!`,
          html: buildDailyMissionsEmail(name),
        },
      });
    }

    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// 3. NOTIFICAÇÃO IN-APP das 18h — incentivo final do dia
// ─────────────────────────────────────────────────────────────────────────────
exports.notificacaoDiariaIncentivo = functions.pubsub
  .schedule('0 18 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today     = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();

    for (const doc of usersSnap.docs) {
      // Não incomoda quem já completou as missões
      const missSnap = await admin.firestore()
        .collection('users').doc(doc.id)
        .collection('daily_missions').doc(today).get();
      const quizzes = missSnap.exists ? (missSnap.data().quizzesDone || 0) : 0;
      if (quizzes >= 3) continue;

      const notifRef = admin.firestore()
        .collection('users').doc(doc.id)
        .collection('notifications').doc();

      batch.set(notifRef, {
        title : '⏰ Última chamada para hoje!',
        body  : 'Faltam poucas horas para as missões encerrarem. Não percas as tuas recompensas! 🪙',
        type  : 'quiz_reminder',
        read  : false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// 4. NOTIFICAÇÃO DA MANHÃ — 9h, bom dia + missões disponíveis
// ─────────────────────────────────────────────────────────────────────────────
exports.notificacaoManha = functions.pubsub
  .schedule('0 9 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today     = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();
    for (const doc of usersSnap.docs) {
      const data   = doc.data();
      const name   = data.nickname || data.name || 'Jogador';
      const streak = data.streak || 0;
      const missSnap = await admin.firestore()
        .collection('users').doc(doc.id)
        .collection('daily_missions').doc(today).get();
      const quizzes = missSnap.exists ? (missSnap.data().quizzesDone || 0) : 0;
      if (quizzes > 0) continue;
      const streakMsg = streak > 0
        ? `Tens ${streak} dias seguidos! Não quebres a sequência! 🔥`
        : 'Começa hoje uma nova sequência de dias!';
      const notifRef = admin.firestore()
        .collection('users').doc(doc.id)
        .collection('notifications').doc();
      batch.set(notifRef, {
        title : `🌅 Bom dia, ${name}!`,
        body  : `As tuas missões diárias já estão disponíveis! ${streakMsg}`,
        type  : 'quiz_reminder',
        read  : false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// 5. NOTIFICAÇÃO DO ALMOÇO — 13h, incentivo durante a pausa
// ─────────────────────────────────────────────────────────────────────────────
exports.notificacaoAlmoco = functions.pubsub
  .schedule('0 13 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today     = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();
    for (const doc of usersSnap.docs) {
      const missSnap = await admin.firestore()
        .collection('users').doc(doc.id)
        .collection('daily_missions').doc(today).get();
      const quizzes = missSnap.exists ? (missSnap.data().quizzesDone || 0) : 0;
      if (quizzes >= 3) continue;
      const remaining = 3 - quizzes;
      const notifRef = admin.firestore()
        .collection('users').doc(doc.id)
        .collection('notifications').doc();
      batch.set(notifRef, {
        title : '🍕 Hora de pausa? Aproveita para treinar!',
        body  : `Falta${remaining > 1 ? 'm' : ''} apenas ${remaining} quiz${remaining > 1 ? 'zes' : ''} para completares a missão! Um quiz leva menos de 2 min ⚡`,
        type  : 'quiz_reminder',
        read  : false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// 6. NOTIFICAÇÃO NOTURNA — 21h, última chamada do dia
// ─────────────────────────────────────────────────────────────────────────────
exports.notificacaoNoite = functions.pubsub
  .schedule('0 21 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today     = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();
    for (const doc of usersSnap.docs) {
      const data   = doc.data();
      const streak = data.streak || 0;
      const missSnap = await admin.firestore()
        .collection('users').doc(doc.id)
        .collection('daily_missions').doc(today).get();
      const quizzes = missSnap.exists ? (missSnap.data().quizzesDone || 0) : 0;
      if (quizzes >= 3) continue;
      const urgency = streak > 0
        ? `O teu streak de ${streak} dias está em risco! 😰`
        : 'Não deixes as missões expirarem!';
      const notifRef = admin.firestore()
        .collection('users').doc(doc.id)
        .collection('notifications').doc();
      batch.set(notifRef, {
        title : '🌙 Última chance antes da meia-noite!',
        body  : `Ainda tens missões por completar. ${urgency} Recompensas expiram em 3h! 🪙`,
        type  : 'quiz_reminder',
        read  : false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// 7. EMAIL SEMANAL — toda segunda-feira às 8h com resumo da semana
// ─────────────────────────────────────────────────────────────────────────────
exports.emailSemanal = functions.pubsub
  .schedule('0 8 * * 1')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();

    for (const doc of usersSnap.docs) {
      const data  = doc.data();
      const email = data.email;
      const name  = data.nickname || data.name || 'Jogador';
      if (!email) continue;

      const pontos = data.pontos || 0;
      const nivel  = Math.floor(pontos / 250) + 1;
      const streak = data.streak || 0;

      const ref = admin.firestore().collection('mail').doc();
      batch.set(ref, {
        to: email,
        message: {
          subject: `🏆 O teu resumo SafeQuest desta semana, ${name}!`,
          html: buildWeeklyEmail(name, pontos, nivel, streak),
        },
      });
    }

    await batch.commit();
    return null;
  });

// ═════════════════════════════════════════════════════════════════════════════
// TEMPLATES HTML 
// ═════════════════════════════════════════════════════════════════════════════

function buildDailyMissionsEmail(name) {
  return `
<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Missões Diárias SafeQuest</title>
</head>
<body style="margin:0;padding:0;background:#F0F4FF;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;">
    <tr><td align="center" style="padding:32px 16px;">
      <table width="100%" style="max-width:480px;">

        <!-- MASCOTE DRAGÃO ANIMADO -->
        <tr><td align="center" style="padding-bottom:16px;">
          <div style="display:inline-block;">
            <svg width="110" height="110" viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg"
              style="filter:drop-shadow(0 8px 24px rgba(26,86,219,0.4));">
              <style>
                @keyframes float  { 0%,100%{transform:translateY(0)}  50%{transform:translateY(-6px)} }
                @keyframes blink  { 0%,90%,100%{transform:scaleY(1)} 95%{transform:scaleY(0.1)} }
                @keyframes shield { 0%,100%{transform:rotate(-8deg)} 50%{transform:rotate(8deg)} }
                @keyframes tail   { 0%,100%{transform:rotate(-12deg) translateX(0)} 50%{transform:rotate(12deg) translateX(4px)} }
                .body-group { animation: float 2.2s ease-in-out infinite; transform-origin: 55px 55px; }
                .eye        { animation: blink 3.5s ease-in-out infinite; transform-origin: 50% 50%; }
                .shield-arm { animation: shield 1.8s ease-in-out infinite; transform-origin: 38px 62px; }
                .tail       { animation: tail 1.4s ease-in-out infinite; transform-origin: 72px 72px; }
              </style>

              <!-- Rabo -->
              <g class="tail">
                <path d="M72 72 Q90 80 96 72 Q102 64 88 60" stroke="#2D7D46" stroke-width="5" fill="none" stroke-linecap="round"/>
                <circle cx="96" cy="72" r="4" fill="#34A85A"/>
              </g>

              <!-- Corpo principal -->
              <g class="body-group">
                <!-- Corpo -->
                <ellipse cx="55" cy="62" rx="22" ry="26" fill="#2ECC71"/>
                <!-- Barriga -->
                <ellipse cx="55" cy="65" rx="13" ry="17" fill="#A8F0C6"/>

                <!-- Asas -->
                <path d="M33 52 Q18 38 22 28 Q28 36 35 44 Z" fill="#27AE60" opacity="0.85"/>
                <path d="M77 52 Q92 38 88 28 Q82 36 75 44 Z" fill="#27AE60" opacity="0.85"/>

                <!-- Cabeça -->
                <ellipse cx="55" cy="36" rx="18" ry="17" fill="#2ECC71"/>

                <!-- Chifres -->
                <path d="M44 22 Q40 12 44 8 Q46 14 47 22" fill="#F39C12"/>
                <path d="M66 22 Q70 12 66 8 Q64 14 63 22" fill="#F39C12"/>

                <!-- Olhos -->
                <g class="eye">
                  <ellipse cx="48" cy="35" rx="5" ry="6" fill="white"/>
                  <ellipse cx="62" cy="35" rx="5" ry="6" fill="white"/>
                  <circle cx="49" cy="36" r="3" fill="#1A1A2E"/>
                  <circle cx="63" cy="36" r="3" fill="#1A1A2E"/>
                  <circle cx="50" cy="34.5" r="1" fill="white"/>
                  <circle cx="64" cy="34.5" r="1" fill="white"/>
                </g>

                <!-- Sorriso -->
                <path d="M48 44 Q55 50 62 44" stroke="#1A5C30" stroke-width="2" fill="none" stroke-linecap="round"/>

                <!-- Narinas -->
                <circle cx="52" cy="41" r="1.5" fill="#1A5C30" opacity="0.6"/>
                <circle cx="58" cy="41" r="1.5" fill="#1A5C30" opacity="0.6"/>

                <!-- Pernas -->
                <ellipse cx="44" cy="84" rx="8" ry="6" fill="#27AE60"/>
                <ellipse cx="66" cy="84" rx="8" ry="6" fill="#27AE60"/>
                <!-- Garras -->
                <path d="M37 87 Q35 91 38 90 M41 89 Q40 93 43 91 M46 89 Q46 93 49 91" stroke="#1A5C30" stroke-width="1.5" fill="none" stroke-linecap="round"/>
                <path d="M59 89 Q59 93 62 91 M64 89 Q65 93 67 91 M69 87 Q72 91 69 90" stroke="#1A5C30" stroke-width="1.5" fill="none" stroke-linecap="round"/>

                <!-- Braço com escudo -->
                <g class="shield-arm">
                  <!-- Braço -->
                  <path d="M33 62 Q22 70 20 78" stroke="#27AE60" stroke-width="6" stroke-linecap="round" fill="none"/>
                  <!-- Escudo -->
                  <path d="M8 70 L8 84 Q15 92 22 84 L22 70 Z" fill="#1A56DB"/>
                  <path d="M11 72 L11 82 Q15 88 19 82 L19 72 Z" fill="#3B82F6"/>
                  <!-- Cruz no escudo -->
                  <line x1="15" y1="73" x2="15" y2="85" stroke="white" stroke-width="2"/>
                  <line x1="9" y1="79" x2="21" y2="79" stroke="white" stroke-width="2"/>
                </g>

                <!-- Chama da boca (pequena) -->
                <path d="M55 48 Q52 54 55 56 Q58 54 55 48" fill="#F39C12" opacity="0.8"/>
                <path d="M55 50 Q53 55 55 57 Q57 55 55 50" fill="#E74C3C" opacity="0.6"/>
              </g>
            </svg>
          </div>
        </td></tr>

        <!-- CARD PRINCIPAL -->
        <tr><td style="background:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header laranja urgência -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="background:linear-gradient(135deg,#F59E0B 0%,#EA580C 100%);padding:28px 32px;text-align:center;">
              <p style="color:rgba(255,255,255,0.9);font-size:12px;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin:0 0 6px;">Missões Diárias</p>
              <h1 style="color:#ffffff;font-size:26px;font-weight:900;margin:0 0 6px;line-height:1.2;">Ei ${name}, estás aqui? 👋</h1>
              <p style="color:rgba(255,255,255,0.85);font-size:14px;margin:0;">As tuas missões de hoje ainda não foram completadas!</p>
            </td></tr>
          </table>

          <!-- Corpo -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:28px 32px;">

              <!-- Alerta streak -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#FEF3C7;border:2px solid #F59E0B;border-radius:14px;margin-bottom:24px;">
                <tr>
                  <td style="padding:14px 16px;font-size:24px;width:40px;">⚠️</td>
                  <td style="padding:14px 16px 14px 0;">
                    <p style="font-size:13px;font-weight:700;color:#92400E;margin:0;">O teu streak pode estar em risco!</p>
                    <p style="font-size:12px;color:#B45309;margin:2px 0 0;">Joga hoje para não perder a sequência de dias consecutivos.</p>
                  </td>
                </tr>
              </table>

              <!-- Missões -->
              <p style="font-size:14px;font-weight:800;color:#1E3A8A;margin:0 0 12px;">🎯 Missões disponíveis hoje</p>

              ${missionRow('🎯','Triathlo do Saber','Faz 3 quizzes hoje','0 / 3','+80 🪙')}
              ${missionRow('⭐','Perfecionista','Termina 1 quiz com 100%','0 / 1','+120 🪙')}
              ${missionRow('🌐','Explorador','Joga em 2 temas diferentes','0 / 2','+60 🪙')}
              ${missionRow('🔥','Máquina de Quizzes','Faz 5 quizzes hoje','0 / 5','+200 🪙')}

              <!-- Total -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0FDF4;border:2px solid #86EFAC;border-radius:12px;margin:16px 0 24px;">
                <tr><td style="padding:12px 16px;text-align:center;">
                  <p style="font-size:13px;color:#166534;font-weight:800;margin:0;">
                    💰 Total disponível hoje: <span style="font-size:18px;color:#16A34A;">460 🪙</span>
                  </p>
                </td></tr>
              </table>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr><td align="center">
                  <a href="#" style="display:inline-block;background:linear-gradient(135deg,#F59E0B,#EA580C);color:#ffffff;text-decoration:none;padding:16px 48px;border-radius:50px;font-size:16px;font-weight:900;letter-spacing:0.5px;box-shadow:0 6px 20px rgba(245,158,11,0.45);">
                    ⚡ Completar Missões
                  </a>
                </td></tr>
              </table>

              <p style="text-align:center;font-size:11px;color:#9CA3AF;margin:16px 0 0;">
                Missões renovam-se todos os dias à meia-noite 🌙
              </p>

            </td></tr>
          </table>

        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px;text-align:center;">
          <p style="font-size:11px;color:#6B7280;margin:0;">
            SafeQuest © ${new Date().getFullYear()} ·
            <a href="#" style="color:#1A56DB;text-decoration:none;">Cancelar emails</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────────────────────

function buildWeeklyEmail(name, pontos, nivel, streak) {
  const nivelLabel = nivel >= 10 ? '🐉 Mestre' : nivel >= 7 ? '🦁 Avançado' : nivel >= 4 ? '🐱 Intermédio' : '🦊 Iniciante';

  return `
<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Resumo Semanal SafeQuest</title>
</head>
<body style="margin:0;padding:0;background:#F0F4FF;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;">
    <tr><td align="center" style="padding:32px 16px;">
      <table width="100%" style="max-width:480px;">

        <!-- MASCOTE DRAGÃO COM TROFÉU -->
        <tr><td align="center" style="padding-bottom:16px;">
          <div style="display:inline-block;">
            <svg width="110" height="110" viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg"
              style="filter:drop-shadow(0 8px 24px rgba(124,58,237,0.4));">
              <style>
                @keyframes float2  { 0%,100%{transform:translateY(0)}  50%{transform:translateY(-6px)} }
                @keyframes blink2  { 0%,90%,100%{transform:scaleY(1)} 95%{transform:scaleY(0.1)} }
                @keyframes trophy  { 0%,100%{transform:rotate(-6deg) translateY(0)} 50%{transform:rotate(6deg) translateY(-3px)} }
                @keyframes shine   { 0%,100%{opacity:0.3} 50%{opacity:1} }
                @keyframes tail2   { 0%,100%{transform:rotate(-10deg)} 50%{transform:rotate(10deg)} }
                .body2  { animation: float2 2s ease-in-out infinite; transform-origin: 55px 55px; }
                .eye2   { animation: blink2 4s ease-in-out infinite; transform-origin: 50% 50%; }
                .trophy { animation: trophy 1.6s ease-in-out infinite; transform-origin: 76px 62px; }
                .shine  { animation: shine 1.2s ease-in-out infinite; }
                .tail2  { animation: tail2 1.3s ease-in-out infinite; transform-origin: 35px 72px; }
              </style>

              <!-- Rabo esquerda -->
              <g class="tail2">
                <path d="M35 72 Q18 80 14 70 Q10 60 24 58" stroke="#7C3AED" stroke-width="5" fill="none" stroke-linecap="round"/>
                <circle cx="14" cy="70" r="4" fill="#9333EA"/>
              </g>

              <g class="body2">
                <!-- Corpo roxo -->
                <ellipse cx="55" cy="62" rx="22" ry="26" fill="#9333EA"/>
                <ellipse cx="55" cy="65" rx="13" ry="17" fill="#DDD6FE"/>

                <!-- Asas -->
                <path d="M33 52 Q18 38 22 28 Q28 36 35 44 Z" fill="#7C3AED" opacity="0.85"/>
                <path d="M77 52 Q92 38 88 28 Q82 36 75 44 Z" fill="#7C3AED" opacity="0.85"/>

                <!-- Cabeça -->
                <ellipse cx="55" cy="36" rx="18" ry="17" fill="#9333EA"/>

                <!-- Chifres dourados (vencedor) -->
                <path d="M44 22 Q40 12 44 8 Q46 14 47 22" fill="#F59E0B"/>
                <circle cx="44" cy="8" r="3" fill="#FBBF24"/>
                <path d="M66 22 Q70 12 66 8 Q64 14 63 22" fill="#F59E0B"/>
                <circle cx="66" cy="8" r="3" fill="#FBBF24"/>

                <!-- Olhos -->
                <g class="eye2">
                  <ellipse cx="48" cy="35" rx="5" ry="6" fill="white"/>
                  <ellipse cx="62" cy="35" rx="5" ry="6" fill="white"/>
                  <circle cx="49" cy="36" r="3" fill="#1A1A2E"/>
                  <circle cx="63" cy="36" r="3" fill="#1A1A2E"/>
                  <circle cx="50" cy="34.5" r="1" fill="white"/>
                  <circle cx="64" cy="34.5" r="1" fill="white"/>
                </g>

                <!-- Sorriso feliz -->
                <path d="M47 44 Q55 52 63 44" stroke="#5B21B6" stroke-width="2.5" fill="none" stroke-linecap="round"/>

                <!-- Bochechas rosadas (feliz) -->
                <ellipse cx="43" cy="42" rx="4" ry="2.5" fill="#FDA4AF" opacity="0.5"/>
                <ellipse cx="67" cy="42" rx="4" ry="2.5" fill="#FDA4AF" opacity="0.5"/>

                <!-- Pernas -->
                <ellipse cx="44" cy="84" rx="8" ry="6" fill="#7C3AED"/>
                <ellipse cx="66" cy="84" rx="8" ry="6" fill="#7C3AED"/>

                <!-- Braço direito segurando troféu -->
                <g class="trophy">
                  <path d="M77 60 Q88 56 90 48" stroke="#7C3AED" stroke-width="6" stroke-linecap="round" fill="none"/>
                  <!-- Troféu -->
                  <rect x="85" y="30" width="16" height="14" rx="3" fill="#F59E0B"/>
                  <path d="M82 32 Q78 38 82 42 L85 42 L85 32 Z" fill="#FBBF24"/>
                  <path d="M101 32 Q105 38 101 42 L98 42 L98 32 Z" fill="#FBBF24"/>
                  <rect x="89" y="44" width="8" height="4" fill="#D97706"/>
                  <rect x="86" y="47" width="14" height="3" rx="1" fill="#D97706"/>
                  <!-- Brilho troféu -->
                  <g class="shine">
                    <line x1="95" y1="32" x2="97" y2="30" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
                    <line x1="91" y1="31" x2="91" y2="28" stroke="white" stroke-width="1.5" stroke-linecap="round"/>
                  </g>
                  <!-- Estrelas à volta -->
                  <g class="shine">
                    <text x="78" y="28" font-size="8">⭐</text>
                  </g>
                </g>
              </g>
            </svg>
          </div>
        </td></tr>

        <tr><td style="background:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header roxo/azul -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="background:linear-gradient(135deg,#1A56DB 0%,#7C3AED 100%);padding:28px 32px;text-align:center;">
              <p style="color:rgba(255,255,255,0.8);font-size:12px;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin:0 0 6px;">Resumo Semanal</p>
              <h1 style="color:#ffffff;font-size:26px;font-weight:900;margin:0 0 6px;">Boa semana, ${name}! 🎉</h1>
              <p style="color:rgba(255,255,255,0.8);font-size:14px;margin:0;">Aqui está o que conquistaste esta semana</p>
            </td></tr>
          </table>

          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:28px 32px;">

              <!-- Stats 3 colunas -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#F8FAFC;border-radius:16px;margin-bottom:24px;overflow:hidden;">
                <tr>
                  <td align="center" style="padding:18px 12px;border-right:1px solid #E5E7EB;">
                    <p style="font-size:30px;margin:0;">⚡</p>
                    <p style="font-size:22px;font-weight:900;color:#1E3A8A;margin:4px 0 2px;">${streak}</p>
                    <p style="font-size:11px;color:#9CA3AF;margin:0;">Dias seguidos</p>
                  </td>
                  <td align="center" style="padding:18px 12px;border-right:1px solid #E5E7EB;">
                    <p style="font-size:30px;margin:0;">🏅</p>
                    <p style="font-size:22px;font-weight:900;color:#1E3A8A;margin:4px 0 2px;">${nivel}</p>
                    <p style="font-size:11px;color:#9CA3AF;margin:0;">Nível atual</p>
                  </td>
                  <td align="center" style="padding:18px 12px;">
                    <p style="font-size:30px;margin:0;">🪙</p>
                    <p style="font-size:22px;font-weight:900;color:#1E3A8A;margin:4px 0 2px;">${pontos}</p>
                    <p style="font-size:11px;color:#9CA3AF;margin:0;">Pontos totais</p>
                  </td>
                </tr>
              </table>

              <!-- Badge de nível -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:linear-gradient(135deg,#EFF6FF,#F5F3FF);border:2px solid #C4B5FD;border-radius:14px;margin-bottom:24px;">
                <tr><td style="padding:16px;text-align:center;">
                  <p style="font-size:28px;margin:0 0 4px;">${nivelLabel.split(' ')[0]}</p>
                  <p style="font-size:14px;font-weight:800;color:#5B21B6;margin:0;">${nivelLabel.split(' ').slice(1).join(' ')}</p>
                  <p style="font-size:12px;color:#7C3AED;margin:4px 0 0;">Faltam ${250 - (pontos % 250)} XP para o nível ${nivel + 1}</p>
                </td></tr>
              </table>

              <!-- Mensagem motivacional -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0FDF4;border-left:4px solid #16A34A;border-radius:0 12px 12px 0;margin-bottom:24px;">
                <tr><td style="padding:14px 16px;">
                  <p style="font-size:13px;font-weight:700;color:#166534;margin:0 0 4px;">💡 Dica da semana</p>
                  <p style="font-size:12px;color:#15803D;margin:0;line-height:1.5;">
                    "Uma boa palavra-passe não é uma palavra do dicionário. Usa frases-passe como <strong>O_Meu_Cão_Chama_se_Boby_2026!</strong>"
                  </p>
                </td></tr>
              </table>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr><td align="center">
                  <a href="#" style="display:inline-block;background:linear-gradient(135deg,#1A56DB,#7C3AED);color:#ffffff;text-decoration:none;padding:16px 48px;border-radius:50px;font-size:16px;font-weight:900;letter-spacing:0.5px;box-shadow:0 6px 20px rgba(26,86,219,0.35);">
                    🚀 Continuar a Aprender
                  </a>
                </td></tr>
              </table>

            </td></tr>
          </table>

        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px;text-align:center;">
          <p style="font-size:11px;color:#6B7280;margin:0;">
            SafeQuest © ${new Date().getFullYear()} ·
            <a href="#" style="color:#1A56DB;text-decoration:none;">Cancelar emails</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — linha de missão
// ─────────────────────────────────────────────────────────────────────────────
function missionRow(icon, title, desc, progress, reward) {
  return `
    <table width="100%" cellpadding="0" cellspacing="0"
      style="background:#F8FAFC;border-radius:12px;margin-bottom:8px;overflow:hidden;border:1px solid #E5E7EB;">
      <tr>
        <td style="padding:12px 14px;font-size:22px;width:38px;">${icon}</td>
        <td style="padding:12px 4px;">
          <p style="font-size:13px;font-weight:700;color:#1E3A8A;margin:0;">${title}</p>
          <p style="font-size:11px;color:#9CA3AF;margin:2px 0 6px;">${desc}</p>
          <!-- Barra de progresso -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td style="background:#E5E7EB;border-radius:8px;height:6px;width:80%;">
                <div style="background:#F59E0B;border-radius:8px;height:6px;width:0%;"></div>
              </td>
              <td style="font-size:10px;color:#9CA3AF;padding-left:8px;white-space:nowrap;">${progress}</td>
            </tr>
          </table>
        </td>
        <td style="padding:12px 14px;text-align:right;white-space:nowrap;vertical-align:top;">
          <span style="background:#FEF3C7;color:#92400E;font-size:11px;font-weight:700;
            padding:4px 8px;border-radius:8px;white-space:nowrap;">${reward}</span>
        </td>
      </tr>
    </table>`;
}
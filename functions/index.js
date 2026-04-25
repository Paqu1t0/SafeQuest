const functions = require('firebase-functions/v1');
const admin     = require('firebase-admin');
admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// DEEP LINK — URL que abre a app SafeQuest (Android Intent + iOS Universal Link)
// Alterar para o teu domínio de Firebase Hosting se configurares Dynamic Links
// ─────────────────────────────────────────────────────────────────────────────
const APP_DEEP_LINK_MISSOES = 'safequest://missoes';
const APP_STORE_URL         = 'https://safequest-4358c.web.app';  // fallback web

// ─────────────────────────────────────────────────────────────────────────────
// 1. PUSH NOTIFICATION — dispara quando cria notif no Firestore
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// 1. PUSH NOTIFICATION — dispara quando cria notif no Firestore
// ─────────────────────────────────────────────────────────────────────────────
exports.sendNotification = functions.firestore
  .document('users/{uid}/notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const uid  = context.params.uid;
    const data = snap.data();

    const user  = await admin.firestore().doc(`users/${uid}`).get();
    const uData = user.data();
    const token = uData?.fcmToken;
    if (!token) return null;

    // Respeita a preferência do utilizador
    if (uData?.pushNotifs === false) return null;

    // AQUI ESTÁ A CORREÇÃO MÁGICA:
    return admin.messaging().send({
      token: token,
      notification: { 
        title: data.title, 
        body: data.body 
      },
      android: { 
        priority: 'high',
        notification: {
          channelId: 'safequest_channel' // 👈 O telemóvel agora já sabe qual é o canal!
        }
      },
      apns: { 
        payload: { 
          aps: { sound: 'default' } 
        } 
      },
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

      // Respeita a preferência do utilizador
      if (data.emailNotifs === false) continue;

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
          subject: `⚡ ${name}, as tuas missões SafeQuest ainda não foram completadas!`,
          html: buildDailyMissionsEmail(name),
        },
      });
    }

    await batch.commit();
    return null;
  });

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS DE NOTIFICAÇÃO
// ─────────────────────────────────────────────────────────────────────────────

/** Escolhe uma mensagem aleatória de um array */
function rand(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

/**
 * Verifica se o utilizador abriu a app hoje.
 * O Flutter grava lastOpenedAt = serverTimestamp() sempre que inicia a app.
 */
function abriuHoje(userData, today) {
  if (!userData.lastOpenedAt) return false;
  const d = userData.lastOpenedAt.toDate
    ? userData.lastOpenedAt.toDate()
    : new Date(userData.lastOpenedAt._seconds * 1000);
  return d.toISOString().split('T')[0] === today;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. NOTIFICAÇÃO DIÁRIA — 19h, relembra quem não abriu a app hoje
// ─────────────────────────────────────────────────────────────────────────────
exports.notificacaoDiaria = functions.pubsub
  .schedule('0 19 * * *')
  .timeZone('Europe/Lisbon')
  .onRun(async () => {
    const today     = new Date().toISOString().split('T')[0];
    const usersSnap = await admin.firestore().collection('users').get();
    const batch     = admin.firestore().batch();

    const titulos = [
      '😴 Esqueceste-te do SafeQuest hoje?',
      '🔥 O teu streak está em perigo!',
      '🛡️ O SafeQuest está à tua espera...',
      '🌅 Ainda não vieste jogar hoje!',
      '⚠️ Protege o teu streak agora!',
    ];
    
    const corpos = (name, streak) => {
      const msgs = [
        `As tuas missões de hoje estão prontas, ${name}! Entra já. 🎮`,
        'Só 2 minutos e o teu streak fica salvo! 🔥',
        'Os teus rivais estão a jogar. Entra já e não percas terreno no ranking! 🏆',
        'Um quiz por dia mantém os hackers à distância. Joga agora! 🛡️',
        `Passaste o dia sem jogar. Um quiz agora salva tudo. Vai lá! 💪`
      ];
      if (streak > 0) msgs.push(`O teu streak de ${streak} dias está em risco! 😰`);
      return rand(msgs);
    };

    for (const doc of usersSnap.docs) {
      const userData = doc.data();
      const name     = userData.nickname || userData.name || 'Jogador';
      const streak   = userData.streak || 0;
      
      // Respeita a preferência do utilizador
      if (userData.pushNotifs === false) continue;
      
      // Só notifica quem NÃO abriu a app hoje
      // ⚠️ COMENTADO PARA PODERES TESTAR "FORÇAR AÇÃO" AGORA MESMO COM O JOGO ABERTO:
      // if (abriuHoje(userData, today)) continue; 

      const notifRef = admin.firestore()
        .collection('users').doc(doc.id)
        .collection('notifications').doc();

      batch.set(notifRef, {
        title    : rand(titulos),
        body     : corpos(name, streak),
        type     : 'quiz_reminder',
        read     : false,
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

      // Respeita a preferência do utilizador
      if (data.emailNotifs === false) continue;

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

// ─────────────────────────────────────────────────────────────────────────────
// 8. EMAIL DE RESET DE PASSWORD — acionado pelo Firestore
//    O Flutter escreve em: users/{uid}/passwordResetRequests/{docId}
//    Esta função envia um email personalizado SafeQuest com o link do Firebase
// ─────────────────────────────────────────────────────────────────────────────
exports.emailResetPassword = functions.firestore
  .document('users/{uid}/passwordResetRequests/{docId}')
  .onCreate(async (snap, context) => {
    const uid = context.params.uid;

    // Vai buscar os dados do utilizador
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (!userDoc.exists) return null;
    const data  = userDoc.data();
    const email = data.email;
    const name  = data.nickname || data.name || 'Jogador';
    if (!email) return null;

    // Gera o link de reset via Firebase Admin (link válido por 1h)
    let resetLink;
    try {
      resetLink = await admin.auth().generatePasswordResetLink(email);
    } catch (e) {
      console.error('Erro ao gerar link de reset:', e);
      return null;
    }

    // Envia o email personalizado SafeQuest
    const ref = admin.firestore().collection('mail').doc();
    await ref.set({
      to: email,
      message: {
        subject: `🔒 ${name}, pediste para redefinir a tua palavra-passe SafeQuest`,
        html: buildPasswordResetEmail(name, resetLink),
      },
    });

    // Marca o pedido como processado
    await snap.ref.update({ processed: true, processedAt: admin.firestore.FieldValue.serverTimestamp() });

    console.log(`Email de reset enviado para ${email}`);
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

        <!-- LOGO SAFEQUEST (ESCUDO) -->
        <tr><td align="center" style="padding-bottom:16px;">
          <div style="display:inline-block;">
            <svg width="90" height="90" viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg"
              style="filter:drop-shadow(0 8px 24px rgba(26,86,219,0.4));">
              <style>
                @keyframes floatLogo { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-4px)} }
                .logoGroup { animation: floatLogo 2.5s ease-in-out infinite; transform-origin: 55px 55px; }
              </style>
              <g class="logoGroup">
                <!-- Escudo -->
                <path d="M55 8 L95 28 L95 60 Q95 90 55 105 Q15 90 15 60 L15 28 Z" fill="#1A56DB"/>
                <path d="M55 14 L89 32 L89 58 Q89 85 55 99 Q21 85 21 58 L21 32 Z" fill="#2563EB"/>
                <path d="M55 20 L83 36 L83 56 Q83 80 55 93 Q27 80 27 56 L27 36 Z" fill="#3B82F6"/>
                <!-- Cadeado -->
                <rect x="42" y="52" width="26" height="22" rx="4" fill="#F59E0B"/>
                <path d="M48 52 Q48 40 55 40 Q62 40 62 52" stroke="#D97706" stroke-width="3.5" fill="none" stroke-linecap="round"/>
                <circle cx="55" cy="62" r="3.5" fill="#92400E"/>
                <rect x="53.5" y="62" width="3" height="6" rx="1.5" fill="#92400E"/>
                <!-- Estrela -->
                <polygon points="55,22 58,30 66,30 60,35 62,43 55,38 48,43 50,35 44,30 52,30" fill="#FBBF24" opacity="0.9"/>
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
                  <!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${APP_DEEP_LINK_MISSOES}" style="height:54px;v-text-anchor:middle;width:220px;" arcsize="50%" fillcolor="#F59E0B"><v:textbox inset="0px,0px,0px,0px"><center style="color:#ffffff;font-family:sans-serif;font-size:16px;font-weight:900;">⚡ Completar Missões</center></v:textbox></v:roundrect><![endif]-->
                  <!--[if !mso]><!-->
                  <a href="${APP_DEEP_LINK_MISSOES}" style="display:inline-block;background:linear-gradient(135deg,#F59E0B,#EA580C);color:#ffffff;text-decoration:none;padding:16px 48px;border-radius:50px;font-size:16px;font-weight:900;letter-spacing:0.5px;box-shadow:0 6px 20px rgba(245,158,11,0.45);">
                    ⚡ Completar Missões
                  </a>
                  <!--<![endif]-->
                </td></tr>
              </table>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:10px;">
                <tr><td align="center">
                  <a href="${APP_STORE_URL}" style="font-size:11px;color:#9CA3AF;text-decoration:underline;">Abrir no browser</a>
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

        <!-- LOGO SAFEQUEST (ESCUDO COM TROFÉU) -->
        <tr><td align="center" style="padding-bottom:16px;">
          <div style="display:inline-block;">
            <svg width="90" height="90" viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg"
              style="filter:drop-shadow(0 8px 24px rgba(124,58,237,0.4));">
              <style>
                @keyframes floatLogo2 { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-4px)} }
                @keyframes shineStar { 0%,100%{opacity:0.4} 50%{opacity:1} }
                .logoGroup2 { animation: floatLogo2 2s ease-in-out infinite; transform-origin: 55px 55px; }
                .starShine { animation: shineStar 1.5s ease-in-out infinite; }
              </style>
              <g class="logoGroup2">
                <!-- Escudo roxo/azul -->
                <path d="M55 8 L95 28 L95 60 Q95 90 55 105 Q15 90 15 60 L15 28 Z" fill="#7C3AED"/>
                <path d="M55 14 L89 32 L89 58 Q89 85 55 99 Q21 85 21 58 L21 32 Z" fill="#8B5CF6"/>
                <path d="M55 20 L83 36 L83 56 Q83 80 55 93 Q27 80 27 56 L27 36 Z" fill="#A78BFA"/>
                <!-- Troféu -->
                <rect x="44" y="48" width="22" height="18" rx="3" fill="#F59E0B"/>
                <path d="M41 50 Q36 56 41 62 L44 62 L44 50 Z" fill="#FBBF24"/>
                <path d="M66 50 Q71 56 66 62 L63 62 L63 50 Z" fill="#FBBF24"/>
                <rect x="49" y="66" width="12" height="4" fill="#D97706"/>
                <rect x="46" y="69" width="18" height="4" rx="2" fill="#D97706"/>
                <!-- Estrela no troféu -->
                <g class="starShine">
                  <polygon points="55,50 57,55 62,55 58,58 60,63 55,60 50,63 52,58 48,55 53,55" fill="white" opacity="0.9"/>
                </g>
                <!-- Estrela topo -->
                <polygon points="55,18 58,26 66,26 60,31 62,39 55,34 48,39 50,31 44,26 52,26" fill="#FBBF24" opacity="0.9"/>
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
                  <a href="${APP_DEEP_LINK_MISSOES}" style="display:inline-block;background:linear-gradient(135deg,#1A56DB,#7C3AED);color:#ffffff;text-decoration:none;padding:16px 48px;border-radius:50px;font-size:16px;font-weight:900;letter-spacing:0.5px;box-shadow:0 6px 20px rgba(26,86,219,0.35);">
                    🚀 Continuar a Aprender
                  </a>
                </td></tr>
              </table>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-top:10px;">
                <tr><td align="center">
                  <a href="${APP_STORE_URL}" style="font-size:11px;color:#9CA3AF;text-decoration:underline;">Abrir no browser</a>
                </td></tr>
              </table>

            </td></tr>
          </table>

        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px;text-align:center;">
          <p style="font-size:11px;color:#6B7280;margin:0;">
            SafeQuest © ${new Date().getFullYear()} · Recebeste este email porque tens notificações ativas.<br>
            <a href="safequest://privacidade" style="color:#1A56DB;text-decoration:none;">Gerir preferências de email</a>
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────────────────────
// TEMPLATE — Email de Reset de Password
// ─────────────────────────────────────────────────────────────────────────────
function buildPasswordResetEmail(name, resetLink) {
  return `
<!DOCTYPE html>
<html lang="pt">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Redefinir Palavra-passe SafeQuest</title>
</head>
<body style="margin:0;padding:0;background:#F0F4FF;font-family:'Segoe UI',Helvetica,Arial,sans-serif;">

  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0F4FF;">
    <tr><td align="center" style="padding:32px 16px;">
      <table width="100%" style="max-width:480px;">

        <!-- LOGO SAFEQUEST (ESCUDO SEGURANÇA) -->
        <tr><td align="center" style="padding-bottom:16px;">
          <div style="display:inline-block;">
            <svg width="90" height="90" viewBox="0 0 110 110" xmlns="http://www.w3.org/2000/svg"
              style="filter:drop-shadow(0 8px 24px rgba(26,86,219,0.4));">
              <style>
                @keyframes floatR { 0%,100%{transform:translateY(0)} 50%{transform:translateY(-4px)} }
                .logoR { animation: floatR 2.5s ease-in-out infinite; transform-origin: 55px 55px; }
              </style>
              <g class="logoR">
                <!-- Escudo azul -->
                <path d="M55 8 L95 28 L95 60 Q95 90 55 105 Q15 90 15 60 L15 28 Z" fill="#1A56DB"/>
                <path d="M55 14 L89 32 L89 58 Q89 85 55 99 Q21 85 21 58 L21 32 Z" fill="#2563EB"/>
                <path d="M55 20 L83 36 L83 56 Q83 80 55 93 Q27 80 27 56 L27 36 Z" fill="#3B82F6"/>
                <!-- Cadeado -->
                <rect x="42" y="52" width="26" height="22" rx="4" fill="#F59E0B"/>
                <path d="M48 52 Q48 40 55 40 Q62 40 62 52" stroke="#D97706" stroke-width="3.5" fill="none" stroke-linecap="round"/>
                <circle cx="55" cy="62" r="3.5" fill="#92400E"/>
                <rect x="53.5" y="62" width="3" height="6" rx="1.5" fill="#92400E"/>
                <!-- Estrela -->
                <polygon points="55,22 58,30 66,30 60,35 62,43 55,38 48,43 50,35 44,30 52,30" fill="#FBBF24" opacity="0.9"/>
              </g>
            </svg>
          </div>
        </td></tr>

        <!-- CARD -->
        <tr><td style="background:#ffffff;border-radius:24px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header azul segurança -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="background:linear-gradient(135deg,#1A56DB 0%,#1E3A8A 100%);padding:28px 32px;text-align:center;">
              <p style="color:rgba(255,255,255,0.9);font-size:12px;font-weight:700;letter-spacing:2px;text-transform:uppercase;margin:0 0 6px;">Segurança da Conta</p>
              <h1 style="color:#ffffff;font-size:24px;font-weight:900;margin:0 0 6px;line-height:1.2;">🔒 Redefinir Palavra-passe</h1>
              <p style="color:rgba(255,255,255,0.85);font-size:14px;margin:0;">Olá ${name}! Recebemos um pedido de redefinição.</p>
            </td></tr>
          </table>

          <!-- Corpo -->
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td style="padding:28px 32px;">

              <!-- Aviso de segurança -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#EFF6FF;border:2px solid #93C5FD;border-radius:14px;margin-bottom:24px;">
                <tr>
                  <td style="padding:14px 16px;font-size:24px;width:40px;">🛡️</td>
                  <td style="padding:14px 16px 14px 0;">
                    <p style="font-size:13px;font-weight:700;color:#1E3A8A;margin:0;">Este link é válido por 1 hora</p>
                    <p style="font-size:12px;color:#3B82F6;margin:2px 0 0;">Se não pediste esta alteração, ignora este email — a tua conta está segura.</p>
                  </td>
                </tr>
              </table>

              <p style="font-size:14px;color:#374151;margin:0 0 24px;line-height:1.6;">
                Para definires uma nova palavra-passe para a tua conta SafeQuest, clica no botão abaixo. 
                Por segurança, este link expira em <strong>1 hora</strong>.
              </p>

              <!-- CTA Reset -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr><td align="center">
                  <a href="${resetLink}" style="display:inline-block;background:linear-gradient(135deg,#1A56DB,#1E3A8A);color:#ffffff;text-decoration:none;padding:16px 48px;border-radius:50px;font-size:16px;font-weight:900;letter-spacing:0.5px;box-shadow:0 6px 20px rgba(26,86,219,0.4);">
                    🔑 Criar Nova Palavra-passe
                  </a>
                </td></tr>
              </table>

              <!-- Dica de segurança -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background:#F0FDF4;border-left:4px solid #16A34A;border-radius:0 12px 12px 0;margin:24px 0 0;">
                <tr><td style="padding:14px 16px;">
                  <p style="font-size:13px;font-weight:700;color:#166534;margin:0 0 4px;">💡 Dica SafeQuest</p>
                  <p style="font-size:12px;color:#15803D;margin:0;line-height:1.5;">
                    Usa uma frase-passe forte como <strong>"Dragao_Azul_Voa_2026!"</strong> — fácil de memorizar e difícil de hackear.
                  </p>
                </td></tr>
              </table>

            </td></tr>
          </table>

        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px;text-align:center;">
          <p style="font-size:11px;color:#6B7280;margin:0;">
            SafeQuest © ${new Date().getFullYear()} · Este email foi enviado automaticamente por razões de segurança.<br>
            Se não reconheces este pedido, <a href="mailto:suporte@safequest.pt" style="color:#1A56DB;">contacta o suporte</a>.
          </p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER — linha de missão (clicável — abre a app ao clicar no card)
// ─────────────────────────────────────────────────────────────────────────────
function missionRow(icon, title, desc, progress, reward, link = APP_DEEP_LINK_MISSOES) {
  return `
    <a href="${link}" style="text-decoration:none;display:block;">
    <table width="100%" cellpadding="0" cellspacing="0"
      style="background:#F8FAFC;border-radius:12px;margin-bottom:8px;overflow:hidden;border:1px solid #E5E7EB;cursor:pointer;transition:box-shadow 0.2s;">
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
    </table>
    </a>`;
}
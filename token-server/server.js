const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { initializeApp, cert, applicationDefault, getApps } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');

const app = express();
app.use(cors());
app.use(express.json());

// Firebase Admin credentials must be configured on the SERVER host,
// never in the Flutter app or committed to this repository.
if (getApps().length === 0) {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    initializeApp({ credential: cert(JSON.parse(serviceAccountJson)) });
  } else {
    initializeApp({ credential: applicationDefault() });
  }
}

// Give the signed-in Firebase user Supabase's required "authenticated"
// claim. The caller can only update their own verified Firebase account.
app.post('/ensure-supabase-role', async (req, res) => {
  try {
    const authHeader = req.headers.authorization || '';
    if (!authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Firebase ID token required' });
    }

    const idToken = authHeader.substring(7).trim();
    const decoded = await getAuth().verifyIdToken(idToken, true);
    const user = await getAuth().getUser(decoded.uid);
    const existingClaims = user.customClaims || {};

    if (existingClaims.role === 'authenticated') {
      return res.json({ success: true, tokenRefreshRequired: false });
    }

    await getAuth().setCustomUserClaims(user.uid, {
      ...existingClaims,
      role: 'authenticated',
    });

    return res.json({ success: true, tokenRefreshRequired: true });
  } catch (error) {
    console.error('Supabase role assignment failed:', error.message);
    return res.status(401).json({ error: 'Could not verify Firebase user' });
  }
});

const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;

app.get('/rtc-token', (req, res) => {
  const channel = req.query.channel;
  const role = req.query.role === 'host' ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

  if (!channel) return res.status(400).json({ error: 'channel is required' });
  if (!APP_ID || !APP_CERTIFICATE) {
    return res.status(500).json({ error: 'Server not configured with Agora credentials' });
  }

  const uid = 0;
  const expireSeconds = 3600;
  const currentTs = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTs + expireSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    APP_ID, APP_CERTIFICATE, channel, uid, role, expireSeconds, privilegeExpiredTs
  );

  res.json({ appId: APP_ID, token });
});

app.get('/', (req, res) => res.send('Agora token server is running ✅'));

// Vercel imports the Express app as a serverless function.
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Token server listening on port ${PORT}`));
}

module.exports = app;

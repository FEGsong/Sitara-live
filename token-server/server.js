const express = require('express');
const cors = require('cors');
const { RtcTokenBuilder, RtcRole } = require('agora-token');

const app = express();
app.use(cors());

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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Token server listening on port ${PORT}`));
import express from 'express';
import { createProxyMiddleware } from 'http-proxy-middleware';
import { GoogleAuth } from 'google-auth-library';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT || 8080;
const AGENT_URL = process.env.VITE_AGENT_SERVER_URL || process.env.AGENT_URL || 'http://localhost:10002';

// Ensure the agent URL config is known
console.log(`Starting BFF Server...`);
console.log(`Proxying backend requests to: ${AGENT_URL}`);

// Set up Google Auth for Identity Tokens (if running on GCP)
const auth = new GoogleAuth();
let targetAudience = AGENT_URL + "/*"; // Target audience is usually the base URL of the Cloud Run service

// Log auth config at startup
(async () => {
  try {
    const projectId = await auth.getProjectId().catch(() => 'unavailable');
    const adc = await auth.getApplicationDefault();
    console.log(`[auth] GoogleAuth initialized.`);
    console.log(`[auth] Project ID: ${projectId}`);
    console.log(`[auth] ADC credential type: ${adc.credential.constructor.name}`);
    console.log(`[auth] Has fetchIdToken: ${'fetchIdToken' in adc.credential}`);
  } catch (e) {
    console.error(`[auth] Failed to inspect credentials at startup: ${e.message}`);
  }
})();

// Proxy all /api traffic to the backend agent securely
const authMiddleware = async (req, res, next) => {
  // 1. Only run if targeting Cloud Run and no token is present
  if (AGENT_URL.includes('.run.app')) {
    try {
      console.log(`[1. Auth-Start] Request to: ${req.url}`);
      
      // Clean audience: No trailing slashes, no wildcards
      const cleanAudience = AGENT_URL.replace(/\/$/, "").replace(/\/\*$/, "");
      
      const client = await auth.getIdTokenClient(cleanAudience);
      
      // Explicit fetchIdToken is the secret sauce for Impersonated/Local flows
      const token = await client.idTokenProvider.fetchIdToken(cleanAudience);
      
      if (token) {
        req.headers['authorization'] = `Bearer ${token}`;
        console.log(`[2. Auth-Success] Token injected into req.headers`);
      }
    } catch (err) {
      console.error(`[Auth-Error] Failed to fetch token: ${err.message}`);
    }
  }
  next();
};

app.use('/api', authMiddleware, createProxyMiddleware({
  target: AGENT_URL,
  changeOrigin: true,
  pathRewrite: { '^/api': '' },
  on: {
    proxyReq: (proxyReq, req, res) => {
      console.log(`[3. Proxy-Fire] (v3) Sending to: ${AGENT_URL}${proxyReq.path}`);
      
      if (req.headers['authorization']) {
        proxyReq.setHeader('X-Serverless-Authorization', req.headers['authorization']);

        // Remove the standard auth header to prevent "header bloat" and log confusion 
        proxyReq.removeHeader('authorization');
        console.log(`[3a. Proxy-Req] Header set: X-Serverless-Authorization`);
      }
    },
    proxyRes: (proxyRes, req, res) => {
      console.log(`[4. Proxy-Res] Status: ${proxyRes.statusCode}`);
    },
    error: (err, req, res) => {
      console.error(`[Proxy-Error] ${err.message}`);
    }
  }
}));

// Serve static compiled Vite files
app.use(express.static(path.join(__dirname, 'dist')));

// Fallback routing for SPA (React Router support)
app.use((req, res, next) => {
  if (req.method === 'GET') {
    res.sendFile(path.join(__dirname, 'dist', 'index.html'));
  } else {
    next();
  }
});

app.listen(PORT, () => {
  console.log(`BFF Server securely listening on port ${PORT}`);
});

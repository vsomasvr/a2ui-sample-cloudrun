# Step-by-Step Guide: Deploying A2UI to a Zero-Trust Cloud Run Environment

This tutorial provides exact, line-by-line instructions on how to take the raw Google A2UI repository and transform its examples into a standalone, production-ready architecture designed for Google Cloud Run, protected by Identity-Aware Proxy (IAP).

---

## Step 1: Clone and Scaffold the Project

First, we will clone the source repository and carve out only the agent and client code we need into a new standalone folder.

```bash
# 1. Clone the upstream A2UI repository
git clone https://github.com/google/a2ui.git

# 2. Create your new standalone repository
mkdir my-a2ui-project
cd my-a2ui-project

# 3. Scaffold the subdirectories
mkdir agent client 

# 4. Copy the Restaurant Finder Agent
cp -r ../a2ui/samples/agent/adk/restaurant_finder/* ./agent/

# 5. Copy the React Client Shell (Ignore the Lit client)
cp -r ../a2ui/samples/client/react/shell/* ./client/
```

You now have the baseline code. Now we must modify it to run independently and securely in the cloud.

---

## Step 2: Detaching Dependencies from the Monorepo

Both the Agent and the Client use local file linking (`file:...` and `path=...`) in their original state. We need to swap these to standard remote package registries (PyPI and NPM).

### 2.1 Update Agent Dependencies (`agent/pyproject.toml`)

Open `agent/pyproject.toml` in your editor. Find the dependencies array and update it:

**Change:**
```toml
dependencies = [
    # ...
    "a2ui-agent-sdk",
]
```
**To:**
```toml
dependencies = [
    # ...
    "a2ui-agent-sdk>=0.2.1",
]
```

At the very bottom of `pyproject.toml`, **delete** this entire block:
```toml
[tool.uv.sources]
a2ui-agent-sdk = { path = "../../../../agent_sdks/python", editable = true }
```

### 2.2 Update Client Dependencies (`client/package.json`)

Open `client/package.json`. Change the `@a2ui/react` dependency to a published version, and add four new backend proxy frameworks that we'll use for our server-side security.

**Change the `dependencies` block to look like this:**
```json
  "dependencies": {
    "@a2a-js/sdk": "^0.3.4",
    "@a2ui/react": "^0.8.0",
    "express": "^5.2.1",
    "google-auth-library": "^10.6.2",
    "http-proxy-middleware": "^3.0.5",
    "react": "^18.3.0",
    "react-dom": "^18.3.0"
  },
```

To support running the entire full-stack locally without issues, also ensure `concurrently` is added to your `devDependencies`:
```json
  "devDependencies": {
    "concurrently": "^9.1.2"
  },
```

Also, update your `scripts` to include a start command for production and helpful scripts for running both client and agent locally:
```json
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "start": "node server.js",
    "serve:agent:restaurant": "cd ../agent && uv run python __main__.py",
    "demo:restaurant": "npm install && concurrently -k -n \"SHELL,REST\" -c \"magenta,blue\" \"npm run dev\" \"npm run serve:agent:restaurant\""
  },
```
*(Notes: If `demo:restaurant` fails to start the Python server, ensure you have the `uv` package manager installed globally via `curl -LsSf https://astral.sh/uv/install.sh | sh` or your local package manager. If you intend to use `concurrently`, ensure you run `npm install --save-dev concurrently` in your client directory).*


---

## Step 3: Modifying Agent Logic for Cloud Security

We need to modify the Python Agent to leverage Vertex AI (instead of just generic Gemini with API keys) and safely accept frontend traffic from Cloud Run domains.

### 3.1 Update the LLM Integration (`agent/agent.py`)

Open `agent/agent.py` and modify `build_llm_agent(self, ...)` to dynamically switch to Vertex AI when deployed:

**Find this line (around line 147):**
```python
    LITELLM_MODEL = os.getenv("LITELLM_MODEL", "gemini/gemini-2.5-flash")
```

**Replace it with:**
```python
    is_vertex = os.getenv("GOOGLE_GENAI_USE_VERTEXAI") == "TRUE"
    default_model = "vertex_ai/gemini-2.5-flash" if is_vertex else "gemini/gemini-2.5-flash"
    LITELLM_MODEL = os.getenv("LITELLM_MODEL", default_model)
```

### 3.2 Update Base URL and CORS (`agent/__main__.py`)

Open `agent/__main__.py`.

1. Allow the Agent's public URL to be configurable via environment variable (this fixes "Mixed Content" HTTP/HTTPS issues).
**Change:**
```python
    base_url = f"http://{host}:{port}"
```
**To:**
```python
    base_url = os.getenv("BASE_URL", f"http://{host}:{port}")
```

2. Relax the CORS regex to accept Cloud Run requests.
**Change:**
```python
        allow_origin_regex=r"http://localhost:\d+",
```
**To:**
```python
        allow_origin_regex=r"(http://localhost:\d+|https://.*\.run\.app)",
```

---

## Step 4: Connecting the Frontend to the Backend

The frontend needs to route traffic properly both locally (via Vite) and in production (via the upcoming Node.js proxy server).

### 4.1 Update API Endpoints

Open `client/src/configs/restaurant.ts` and modify the default server URL fallback to support Vite environments:

**Change:**
```typescript
  serverUrl: 'http://localhost:10002',
```
**To:**
```typescript
  serverUrl: import.meta.env.VITE_AGENT_SERVER_URL || 'http://localhost:10002',
```

### 4.2 Configure Local Proxy (`client/vite.config.ts`)

Open `client/vite.config.ts`. In the `server` block, add proxy forwarding so local frontend traffic correctly mimics our production architecture:

**Add this into the `server: { ... }` block:**
```typescript
    proxy: {
      '/api': {
        target: process.env.AGENT_URL || 'http://localhost:10002',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
```

---

## Step 5: Constructing the Security Proxy layer (BFF)

We never want to expose Identity Tokens to a user's browser. Therefore, we use a Backend-For-Frontend (BFF) that mints an OIDC token and attaches it to proxy requests sent from the React UI to the Cloud Run Agent.

Create a new file `client/server.js` and paste this exact implementation:

```javascript
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

console.log(`Starting BFF Server... Proxying to: ${AGENT_URL}`);

const auth = new GoogleAuth();

const authMiddleware = async (req, res, next) => {
  if (AGENT_URL.includes('.run.app')) {
    try {
      const cleanAudience = AGENT_URL.replace(/\/$/, "").replace(/\/\*$/, "");
      const client = await auth.getIdTokenClient(cleanAudience);
      const token = await client.idTokenProvider.fetchIdToken(cleanAudience);
      
      if (token) {
        req.headers['authorization'] = `Bearer ${token}`;
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
      if (req.headers['authorization']) {
        proxyReq.setHeader('X-Serverless-Authorization', req.headers['authorization']);
        proxyReq.removeHeader('authorization');
      }
    }
  }
}));

app.use(express.static(path.join(__dirname, 'dist')));

app.use((req, res, next) => {
  if (req.method === 'GET') { res.sendFile(path.join(__dirname, 'dist', 'index.html')); } 
  else { next(); }
});

app.listen(PORT, () => { console.log(`BFF Server securely listening on port ${PORT}`); });
```

---

## Step 6: DevOps and Containerization

To run these applications on Cloud Run, we need to containerize both. 

### 6.1 Agent Dockerfile

Create `agent/Dockerfile`. This multi-stage build securely leverages `uv` to pull our new PyPI dependencies:

```dockerfile
# Stage 1: Build the environment
FROM python:3.13-slim AS builder
WORKDIR /app
RUN pip install --no-cache-dir uv
COPY pyproject.toml uv.lock ./
# Note: In production you must generate a uv.lock using `uv lock` beforehand.
ENV UV_COMPILE_BYTECODE=1
RUN uv sync --no-install-project --no-dev --locked

# Stage 2: Runtime Environment
FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PATH="/app/.venv/bin:$PATH" PORT=8080
WORKDIR /app
RUN groupadd -r agentgroup && useradd -r -g agentgroup agentuser && chown -R agentuser:agentgroup /app
COPY --from=builder /app/.venv /app/.venv
COPY --chown=agentuser:agentgroup . .
USER agentuser
EXPOSE 8080
CMD sh -c "python __main__.py --host 0.0.0.0 --port ${PORT:-8080}"
```

Create `agent/cloudbuild.yaml`:
```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', '$_REGION-docker.pkg.dev/$PROJECT_ID/$_REPO_NAME/$_IMAGE_NAME:latest', '.']
substitutions:
  _REGION: 'us-central1'
  _REPO_NAME: 'a2ui-sample'
  _IMAGE_NAME: 'a2ui-restaurant-agent'
images:
  - '$_REGION-docker.pkg.dev/$PROJECT_ID/$_REPO_NAME/$_IMAGE_NAME:latest'
```

### 6.2 Client Dockerfile

Create `client/Dockerfile`. This builds the React app, then serves it using our Express proxy:

```dockerfile
# Stage 1: Build the React frontend
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ENV VITE_AGENT_SERVER_URL=/api
RUN npm run build

# Stage 2: Serve via Node Express (BFF)
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY --from=builder /app/dist ./dist
COPY server.js ./
RUN chown -R node:node /app
USER node
EXPOSE 8080
ENV PORT=8080

CMD ["node", "server.js"]
```

Create `client/cloudbuild.yaml`:
```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', '$_REGION-docker.pkg.dev/$PROJECT_ID/$_REPO_NAME/$_IMAGE_NAME:latest', '.']
substitutions:
  _REGION: 'us-central1'
  _REPO_NAME: 'a2ui-sample'
  _IMAGE_NAME: 'a2ui-restaurant-client'
images:
  - '$_REGION-docker.pkg.dev/$PROJECT_ID/$_REPO_NAME/$_IMAGE_NAME:latest'
```

---

## Step 7: The Terraform Infrastructure

Create a `terraform/` folder in your project root to start layering up your environments. To establish the Zero-Trust Architecture:

1. **Service Accounts**: Create individual Service Accounts for both Cloud Runs (`client-sa` and `agent-sa`).
2. **Deploy Cloud Runs**: Point the Cloud Run resources to your uploaded Docker images.
    * Set `ingress = INGRESS_TRAFFIC_ALL` on the Client.
    * Set `ingress = INGRESS_TRAFFIC_INTERNAL_ONLY` (or IAP restricted ingress) on the Agent. 
3. **IAM Permissions**: 
    * Grant `roles/aiplatform.user` to the `agent-sa`.
    * Grant `roles/run.invoker` strictly to the local `client-sa` on the backend Agent Service.
4. **Identity Aware Proxy (IAP)**: Hook IAP into the Cloud Run Load balancer configured for the Client, securing the entire front door with `google_iap_web_backend_service_iam_member` ensuring authenticated access to your dashboard!

---

## Step 8: Local Running and Testing

There are two primary ways to test your setup: Active Full-Stack Development (running both the raw agent and client locally) and BFF Proxy Verification (running the Node Express server locally against a deployed agent).

### A. Active Full-Stack Development

To develop both the React frontend and the AI Agent locally with hot-reloading:

1. **Configure Vertex AI Credentials:**
   The Python Agent needs to know your Google Cloud Project and region to access Vertex AI models. Create an `.env` file inside the `agent/` directory:
   
   ```bash
   # inside my-a2ui-project
   cp agent/.env.example agent/.env
   ```
   Now edit `agent/.env` to ensure Vertex AI is toggled on and your configuration is set:
   
   ```env
   GOOGLE_GENAI_USE_VERTEXAI=TRUE
   VERTEX_PROJECT=your-google-cloud-project-id
   VERTEX_LOCATION=us-central1
   ```

2. **Run the Developer Stack:**
   Authenticate your local terminal so the Agent has access to Vertex AI, then use the `concurrently` script we added to automatically launch both servers:
   
   ```bash
   gcloud auth application-default login
   cd client
   npm run demo:restaurant
   ```

   *Your local React app will now be running on port 5003 and correctly routing api requests to your local Python Agent!*

---

### B. BFF Proxy Verification (Testing Deployed Agents)

Before deploying the final iteration of your client container, you can independently verify that your Node.js proxy server is minting and injecting Identity-Aware Proxy tokens correctly to talk to your *Remote* Agent.

#### 1. Authenticate with the Client Service Account

Since the backend Agent requires the `roles/run.invoker` permission securely tied to the Client Service Account, you must impersonate it locally:

```bash
# Impersonate the service account (replace with your actual SA email)
gcloud auth application-default login --impersonate-service-account=client-sa@YOUR_PROJECT.iam.gserviceaccount.com
```

### 2. Start the Local BFF Proxy

Navigate to your client shell directory, provide the deployed Agent URL, and start the node proxy:

```bash
cd client/shell
export AGENT_URL="https://YOUR_DEPLOYED_AGENT_URL.run.app"
npm run start
```
*Note: This starts the `server.js` Express proxy locally on port 8080.*

### 3. Verify the Proxy locally

To securely test that the BFF proxy successfully injects OIDC tokens from the impersonated service account into requests bound for the remote backend, run a direct `curl` against your local proxy:

```bash
curl -X POST "http://localhost:8080/api/" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": 1,
    "params": {
      "message": {
        "messageId": "123456",
        "role": "user",
        "kind": "message",
        "parts": [
          {"text": "Find me the top 3 pizza places in New York"}
        ]
      }
    }
  }'
```

If you receive a fully structured JSON-RPC response containing restaurant results, your token exchange, CORS configuration, and security architecture are mapped perfectly!

You have now successfully transformed a local development monorepo example into an enterprise-ready, token-proxied web service!

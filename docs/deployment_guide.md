# A2UI Minimum Viable Agent - Deployment Guide

This guide details the complete, end-to-end setup and deployment of the A2UI agent to Google Cloud Run, adhering to ultimate best practices for infrastructure mapping, security, and container image optimization.

## System Architecture

The deployment consists of three major components:
1.  **Google Artifact Registry**: To securely store Docker images tagged dynamically by Cloud Build.
2.  **Google Cloud Build**: To streamline, cache, and securely push container builds.
3.  **Google Cloud Run (v2)**: Executing the agent as a serverless container.
4.  **Dedicated IAM Service Account**: Providing the principle of least-privilege for the Cloud Run execution, explicitly bound only to necessary Vertex AI permissions.

---

## Prerequisites

Before executing the deployment steps, ensure you have:
1. Authenticated your `gcloud` CLI:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
2. Defined your environment variables in the Terraform specifications:
   Located in `terraform/environments/prod/terraform.tfvars`:
   ```hcl
   project_id         = "a2ui-demos"
   region             = "us-central1"
   registry_repo_name = "a2ui-sample"
   agent_image_url    = "us-central1-docker.pkg.dev/a2ui-demos/a2ui-sample/a2ui-restaurant-agent:latest"
   use_vertex_ai      = true
   ```

---

## Deployment Steps

Because Cloud Build pushes an image that Cloud Run depends on, and Cloud Build pushes to a repository that Terraform must initially create, the workflow occurs in exactly three structured steps:

### Step 1. Deploy the Artifact Registry Hub
First, generate the Google Artifact Registry repository to host your agent container images.

```bash
cd terraform/environments/prod
terraform init
terraform apply -target=module.artifact_registry
```
*(Confirm with `yes` when prompted)*

### Step 2. Build and Publish the Agent Image
Execute Google Cloud Build to trigger the multi-stage Docker build process described in `agent/cloudbuild.yaml`. This process is accelerated heavily by layer caching and relies on the `.gcloudignore` boundaries.

```bash
cd ../../../agent
gcloud builds submit --config cloudbuild.yaml .
```
*Cloud Build will automatically tag images uniquely with the execution `$BUILD_ID` and a moving `latest` tag.*

### Step 3. Deploy the Cloud Run Service
Finally, instruct Terraform to provision the actual agent API container mapping to the newly deployed container image. This sequence creates the dedicated Service Account, maps the environmental variables, and turns on the live Cloud Run URL.

```bash
cd ../terraform/environments/prod
terraform apply
```
*(Confirm with `yes` when prompted)*

---
For redeployment
gcloud run services update a2ui-client-prod --image us-central1-docker.pkg.dev/vsoma-demos/a2ui-sample/a2ui-restaurant-agent:latest --region us-central1 --project vsoma-demos

---

### Verifying Deployment & Testing

Because the Cloud Run service is securely locked behind Google Cloud IAM, you cannot simply `curl` it without an authentication token.

#### 1. Setup Environment Variables
First, grab the newly deployed Cloud Run URL from your Terraform outputs, and generate an Identity Token using your active `gcloud` session credentials:

```bash
export AGENT_URL="https://a2ui-agent-prod-<hash>-uc.a.run.app"
export ID_TOKEN=$(gcloud auth print-identity-token)
```

#### 2. Smoke Test (The Agent Configuration Card)
To cleanly verify that the Cloud Run networking and IAM authentication are correctly configured, HTTP GET the standard A2A application card. If this returns JSON, your configuration is flawless:

```bash
curl -i -X GET "${AGENT_URL}/.well-known/agent-card.json" \
  -H "Authorization: Bearer ${ID_TOKEN}"
```

#### 3. Trigger the ADK JSON-RPC Engine
To actually generate content via the AI, pass a strictly formatted JSON-RPC `2.0` envelope invoking the `"message/send"` method exposed by the `A2AStarletteApplication`:

```bash
curl -X POST "${AGENT_URL}/" \
  -H "Authorization: Bearer ${ID_TOKEN}" \
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

## Client Deployment & Testing

This section covers how to build, deploy, and locally test the Frontend Client (BFF and Web UI).

### 1. Build and Publish the Client Image

Navigate to the client shell directory and submit the build:

```bash
cd client/shell
gcloud builds submit --config cloudbuild.yaml .
```

### 2. Deploy the Client

Apply the Terraform configuration to provision the client Cloud Run service:

```bash
cd terraform/environments/prod
terraform init
terraform apply
```

For redeployment
gcloud run services update a2ui-client-prod --image us-central1-docker.pkg.dev/vsoma-demos/a2ui-sample/a2ui-restaurant-client:latest --region us-central1 --project vsoma-demos

---

### 3. Local Testing

Before deploying the final version or to debug locally, you can run the client BFF proxy using the impersonated service account credentials constraint.

1. Authenticate with the Client Service Account:
   ```bash
   gcloud auth application-default login --impersonate-service-account=a2ui-client-prod-sa@vsoma-demos.iam.gserviceaccount.com
   ```

2. Start the local server:
   ```bash
   cd client/shell
   export AGENT_URL="<YOUR_DEPLOYED_AGENT_URL>"
   npm run start
   ```

3. Test the local proxy via `curl`:
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

### 4. Final Verification

Finally, if you made changes locally, ensure everything is deployed to the remote environments:

```bash
cd terraform/environments/prod
terraform apply
```

Test the fully deployed Client via its remote HTTPS Cloud Run endpoint.


##
1. The "Native" 403 Explained
When you use Native IAP, Google manages the "front door" for you directly at the .run.app endpoint.

If you have allUsers invoker: Anyone can hit the URL. IAP sees the request, asks for login, and since the service allows anyone to invoke it, it works.

If you remove allUsers: Cloud Run now checks IAM before it even lets IAP finish the job. If you (the person in the browser) don't have the roles/run.invoker role, Cloud Run stops you with a 403 before IAP can "represent" you.

Scenario                | Can you use the Web UI? | Can you bypass IAP via CLI? | Security Posture
User has Invoker + IAP  | Yes                     | Yes (using gcloud tokens) | Lower (Redundant keys)
User has IAP Only       | Yes                     | No (403 Forbidden)        | Higher (Zero Trust)
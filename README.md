# Digital Twin

This project is a Digital Twin application—a personalized AI assistant modeled to answer questions and interact based on specific provided context. Built as part of the "AI in MLOps" course (Week 2, Day 5) by Ed Donner, it utilizes a modern serverless cloud architecture on AWS to provide a highly scalable, low-latency chatbot experience powered by Amazon Bedrock.

## 🚀 Tech Stack

**Frontend:**
- **Framework:** Next.js 15 (App Router, Static Export)
- **Language:** TypeScript
- **Hosting:** Amazon S3 + CloudFront

**Backend:**
- **Framework:** FastAPI (wrapped with Mangum for AWS Lambda compatibility)
- **Language:** Python 3.12
- **Environment:** AWS Lambda + API Gateway (HTTP API v2)
- **AI / LLM:** Amazon Bedrock (`us.amazon.nova-lite-v1:0`)
- **Memory Storage:** Amazon S3 (for conversation history)
- **Packaging:** Docker (`public.ecr.aws/lambda/python:3.12`), `uv`

**Infrastructure & Deployment:**
- **IaC:** Terraform
- **CI/CD Configuration:** GitHub Actions + AWS OIDC Authentication
- **Networking:** Route53, AWS Certificate Manager (ACM)

---

## 🏗️ Architecture Diagram

The system follows a completely serverless architecture using AWS managed services. 

```mermaid
graph TD
    Client[User Browser]
    
    subgraph AWS Cloud
        CF[Amazon CloudFront]
        S3_FE[(S3 Bucket: Frontend)]
        API_GW[API Gateway HTTP API v2]
        Lambda[AWS Lambda: FastAPI]
        Bedrock((Amazon Bedrock))
        S3_MEM[(S3 Bucket: Memory)]
        Route53((Route53 / ACM))
        
        Route53 -.-> |DNS / TLS| CF
        CF --> |Static Assets| S3_FE
        CF --> |API Requests| API_GW
        API_GW --> Lambda
        Lambda <--> |Inference| Bedrock
        Lambda <--> |Load/Save State| S3_MEM
    end
    
    Client -->|HTTPS| Route53
```

---

## 🔄 Data Flow Diagram

When a user interacts with the Digital Twin, the data flows across the stack to enrich the prompt with historical context before inference:

```mermaid
graph LR
    User([User Chat Input]) --> FE[Next.js Frontend]
    FE --> |HTTP POST /chat| API[API Gateway]
    API --> Handler[Lambda FastAPI Handler]
    
    subgraph Backend Execution
        Handler <--> |Fetch & Update Context| Memory[(S3 Memory Bucket)]
        Handler --> |Contextualized Prompt| LLM[Amazon Bedrock]
        LLM --> |AI Response| Handler
    end
    
    Handler --> |JSON Response| API
    API --> FE
    FE --> |Render Message| User
```

---

## ⚙️ Build & Deployment Sequence

The project handles build processes for both the frontend (Node.js) and the backend (Python application packaged via `uv` and Docker), before deploying infrastructure via Terraform.

```mermaid
sequenceDiagram
    participant Dev as Developer / CI Pipeline
    participant BE as Backend Build (uv/Docker)
    participant FE as Frontend Build (Next.js)
    participant TF as Terraform
    participant AWS as AWS Cloud
    
    Dev->>FE: `npm run build`
    FE-->>Dev: Output compiled to `./out` (Static Export)
    
    Dev->>BE: `uv run deploy.py`
    BE-->>Dev: Packaged `lambda-deployment.zip` created
    
    Dev->>TF: `terraform apply`
    TF->>AWS: Provision S3, API Gateway, Lambda, CloudFront
    AWS-->>TF: Infrastructure Ready outputs
    
    Dev->>AWS: Sync frontend `./out` to S3 Bucket
    Dev->>AWS: Upload `.zip` to Lambda (if not via TF directly)
    
    AWS-->>Dev: Deployment fully live & functional
```

---

## 🧩 Build Dependencies

The following flowchart maps out how the different components (Backend, Lambda packaging, Terraform, Frontend, and CI/CD) relate to each other and trigger deployments.

```mermaid
flowchart TD
    subgraph DATA["📁 backend/data/"]
        D["facts.json, linkedin.pdf\nsummary.txt, style.txt"]
    end

    subgraph PY["🐍 Backend Python — Steps 1–4"]
        R["① resources.py\nreads data/ at cold-start import"]
        C["② context.py\nprompt() returns full system string"]
        S["③ server.py\nFastAPI · /chat · /health\ncall_openai() · USE_S3 dual-mode memory"]
        H["④ lambda_handler.py\nhandler = Mangum(app)"]
        R --> C --> S --> H
    end

    subgraph PKG["📦 Lambda Packaging — Steps 5–6"]
        REQ["⑤ requirements.txt\nfastapi · uvicorn · mangum · boto3\nopenai · pypdf · python-dotenv · python-multipart"]
        DP["⑥ deploy.py + Docker\npublic.ecr.aws/lambda/python:3.12\n--platform linux/amd64"]
        ZIP["lambda-deployment.zip ✅"]
        REQ --> DP --> ZIP
    end

    subgraph TF["🏗️ Terraform — Steps 7–10"]
        TV["⑦ versions.tf + backend.tf\nAWS provider 6.x · partial S3 backend"]
        VA["⑧ variables.tf + tfvars\nenv · openai_model · lambda_timeout · throttle"]
        MN["⑨ main.tf\nS3-memory · S3-frontend · IAM\nLambda · API Gateway · CloudFront"]
        OU["⑩ outputs.tf\napi_gateway_url · cloudfront_url\ns3_frontend_bucket"]
        TV --> MN
        VA --> MN
        MN --> OU
    end

    subgraph FE["⚛️ Frontend Build — Steps 11–12"]
        TX["⑪ components/twin.tsx\nreads NEXT_PUBLIC_API_URL at build time"]
        EP[".env.production\nNEXT_PUBLIC_API_URL = api_gateway_url"]
        NC["next.config.ts\noutput: 'export' → enables static ./out/"]
        NB["npm run build\noutput: export → ./out/ static bundle"]
        SS["aws s3 sync ./out\n→ S3 frontend bucket ✅"]
        EP --> NB
        TX --> NB
        NC --> NB
        NB --> SS
    end

    subgraph CICD["🔄 CI/CD — Steps 12–14"]
        DS["⑫ scripts/deploy.sh\n1·build zip  2·terraform apply  3·write .env\n4·npm build  5·s3 sync"]
        DY["⑬ .github/workflows/deploy.yml\nOIDC auth · run deploy.sh\ncapture outputs · CF invalidate\ntrigger: push main or workflow_dispatch"]
        DD["⑭ .github/workflows/destroy.yml\nmanual-only · type env name to confirm\nrun destroy.sh via OIDC"]
        DSH["scripts/destroy.sh\nrequires env param · checks workspace exists\ndestroys TF resources + empties S3"]
        DD --> DSH
    end

    D --> R
    D --> DP
    R --> DP
    C --> DP
    S --> DP
    H --> DP
    ZIP -->|"filebase64sha256 hash"| MN
    OU -->|"terraform output -raw api_gateway_url"| EP
    DY -->|"on: push to main"| DS
    DS -.->|"step 1: build zip"| DP
    DS -.->|"step 2: tf apply"| MN
    DS -.->|"step 3: write env"| EP
    DS -.->|"step 4-5: build + sync"| SS
```

---

## 🛠️ Testing & Development
- **Backend Deployment Script:** `backend/deploy.py` packages the backend for Lambda.
- **Full Deploy Script:** `scripts/deploy.sh` wraps the complete build, sync, and Terraform apply processes.

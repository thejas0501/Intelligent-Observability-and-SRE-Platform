<div align="center">
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white" alt="AWS" />
  <img src="https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white" alt="Terraform" />
  <img src="https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white" alt="Prometheus" />
  <img src="https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white" alt="Grafana" />
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" />
</div>

<h1 align="center">Intelligent Observability & SRE Platform</h1>

> **This is not a simple "Hello World" dashboard.** It is a production-grade Site Reliability Engineering platform built from scratch, reflecting the exact reliability practices and multi-window SLO alerting strategies utilized by global engineering teams at Google and Netflix.

This project delivers a complete, immutable AWS infrastructure, a fully instrumented microservice application with built-in chaos engineering, a comprehensive metrics/logs/traces observability triad, and a sophisticated AIOps anomaly detection loop. It is designed to demonstrate deep, practical expertise in modern infrastructure, operational visibility, and automated incident remediation.

---

## 📑 Table of Contents
1. [Architecture & Data Flow](#-architecture--data-flow)
2. [Technology Stack & Tradeoffs](#-technology-stack--tradeoffs)
3. [Deep Dive: The SLO Engine & Burn Rates](#-the-slo-engine-multi-window-burn-rates)
4. [Deep Dive: AIOps Anomaly Detection Loop](#-aiops-the-anomaly-detection-loop)
5. [Infrastructure & Security Posture](#-infrastructure--security-posture)
6. [Application & Chaos Engineering](#-application--chaos-engineering)
7. [Key Engineering Decisions](#-key-engineering-decisions)
8. [What I Learned](#-what-i-learned)
9. [Setup & Deployment Instructions](#-setup--deployment-instructions)
10. [Part of a 5-Project SRE Portfolio](#-part-of-a-5-project-sre-portfolio)

---

## 🏛️ Architecture & Data Flow

The architecture focuses on isolation, scalability, and robust telemetry ingestion. The application operates in public subnets while the data layer remains entirely isolated in private subnets, ensuring a zero-trust boundary.

```text
                                  [ INTERNET ]
                                        |
+---------------------------------------|---------------------------------------+
| AWS VPC (ap-south-1)                  v                                       |
|                                [ IGW / NAT ]                                  |
|                                       |                                       |
|  +------------------------------------|------------------------------------+  |
|  | PUBLIC SUBNET (AZ-a / AZ-b)        v                                    |  |
|  |                     +-----------------------------+                     |  |
|  |                     |  EC2 (t3.micro)             |                     |  |
|  |                     |  - Flask App (Python 3.9)   | ---> [ Node Exporter]  |
|  |                     |  - Custom App Metrics       | ---> [ Prometheus ] |  |
|  |                     |  - Systemd Managed Services |                     |  |
|  |                     +-----------------------------+                     |  |
|  +---------------------------|--------|------------------------------------+  |
|                              |        |                                       |
|  +---------------------------|--------|------------------------------------+  |
|  | PRIVATE SUBNET            v        |                                    |  |
|  |                     +-----------+  |    +-----------------------------+ |  |
|  |                     | RDS MySQL |  +--> | AIOps Loop                  | |  |
|  |                     | (8.0)     |       | - CloudWatch ML Anomaly     | |  |
|  |                     | db.t3.m   |       | - CW Alarms -> SNS Topic    | |  |
|  |                     +-----------+       | - Lambda (Auto-Diagnosis)   | |  |
|  +-----------------------------------------+-----------------------------+ |  |
+-------------------------------------------------------------------------------+
                                        | (HTTPS Remote Write)
                                        v
                 [ Grafana Cloud (RED Dashboards & SLO Tracking) ]
```

### Data Flow Execution
1. **Traffic Ingress:** Users hit the Flask application via the public IP.
2. **Telemetry Generation:** `prometheus-client` intercepts requests to track duration, method, and active connections.
3. **Scraping:** Local Prometheus server scrapes the Flask app and Node Exporter every 15s.
4. **SLO Computation:** Prometheus Recording Rules calculate error budgets and burn rates dynamically.
5. **Visualization:** Data is securely remote-written to Grafana Cloud.
6. **AIOps:** CloudWatch ingests key metrics and utilizes Machine Learning bands to detect non-deterministic anomalies, triggering SNS and Lambda.

---

## 🛠️ Technology Stack & Tradeoffs

Every tool was deliberately selected. I prioritize open-source reliability standards over proprietary vendor lock-in wherever possible, except where managed services provide significant operational advantages (e.g., ML Anomaly Detection).

### Infrastructure as Code (IaC)
*   **Terraform (1.7) & AWS Provider (5.100):** Chosen for immutable infrastructure declarations. By modularizing the setup (`networking`, `compute`, `database`, `iam`, `lookout`), the codebase remains highly readable and isolated.
*   **Tradeoff:** I used a remote S3 state backend. While local state is faster for solo projects, S3 state locking and versioning is mandatory in any real team environment, so I implemented it here.

### Application Layer
*   **Python (3.9) & Flask (3.1):** Chosen for simplicity and direct control over the WSGI layer. This allowed me to deeply instrument the HTTP request lifecycle without the black-box abstraction of heavier frameworks.
*   **MySQL (8.0) via RDS:** Relational integrity for the simulated orders data. Deployed into a private subnet to enforce a strict security boundary.

### Observability & SRE Core
*   **Prometheus (2.51):** The industry standard for time-series metrics. I chose a pull-based model for core metrics to maintain granular control over scrape intervals and recording rule evaluation.
*   **Grafana Cloud:** Used for its powerful visualization of the RED metrics (Rate, Errors, Duration) via 7 distinct dashboard panels.
*   **AWS CloudWatch & Lambda (AIOps):** Used specifically for Machine Learning anomaly detection, an area where cloud-native managed services outperform self-hosted heuristics.

---

## 🚦 The SLO Engine: Multi-Window Burn Rates

This is the crown jewel of the platform. Dashboards are for humans; alerts are for machines. Instead of alerting on raw CPU spikes or static error thresholds (which leads to alert fatigue), I implemented Google's SRE Workbook methodology: **alerting on Error Budget Burn Rates.**

I defined three strict Service Level Objectives (SLOs):
1.  **Availability:** 99.9% (Allows 43.2 minutes of error budget/month)
2.  **Latency:** P95 < 500ms on 95% of requests
3.  **Error Rate:** < 1% overall error rate

### The Burn Rate Alerting Strategy

Alerting when "errors > 1%" is fundamentally flawed because it doesn't account for time or impact. My Prometheus configuration utilizes 8 distinct recording rules evaluating over 5m, 1h, and 6h windows.

*   🔴 **SLOFastBurn (1h window, 14x burn rate):** The error budget will be entirely exhausted in ~2 hours. This is a critical `P1` alert that pages the on-call engineer immediately.
*   🟡 **SLOSlowBurn (6h window, 6x burn rate):** The budget is bleeding slowly and will be gone in 5 days. This creates a standard Jira/tracking ticket for the team to investigate during normal business hours.
*   🟡 **SLOLatencyViolation:** P95 latency exceeds 500ms consistently.
*   🔴 **FlaskAppDown:** Synthetics fail to reach the application for > 1 minute.

### Real-World Validation
To prove this works, I built a chaos engineering endpoint (`/api/stress`) that injects artificial 500 errors into the system. During an active chaos run, the system recorded a **10.3% error rate**, resulting in a massive **40-50x burn rate**. The `SLOFastBurn` alert fired exactly as designed, while the slow burn remained silent for short-lived spikes.

---

## 🧠 AIOps: The Anomaly Detection Loop

Traditional static thresholds struggle with seasonality (e.g., higher traffic on Friday evenings). To combat this, I implemented an automated AIOps pipeline.

1.  **Metric Ingestion:** The Flask app pushes custom telemetry (`ErrorRate`, `RequestCount`, `ActiveRequests`) to a custom CloudWatch namespace (`SREPlatform/FlaskApp`) every 60 seconds.
2.  **Machine Learning Bands:** CloudWatch ML Anomaly Detection builds historical bands around expected `ErrorRate` and `RequestCount`.
3.  **Alarm Evaluation:** An alarm triggers if the metric breaches the ML band (`ANOMALY_DETECTION_BAND(m1, 2)`) for 2 consecutive evaluation periods.
4.  **Pub/Sub Decoupling:** The alarm payload is pushed to an SNS Topic.
5.  **Automated Response:** A Python 3.11 Lambda function triggers via SNS. Executing in an average of **437ms**, it auto-diagnoses the payload context and routes an actionable incident notification.

This loop successfully identified the 10.3% error rate anomaly during chaos testing entirely dynamically, with zero hard-coded thresholds.

---

## 🏗️ Infrastructure & Security Posture

The platform is backed by 25 distinct Terraform resources, deployed with zero manual console clicks.

*   **Network Isolation:** The VPC spans 2 Availability Zones (`ap-south-1a`, `ap-south-1b`). The RDS instance is deployed strictly in the private subnets.
*   **Security Groups:** The RDS security group is configured to *only* accept traffic originating from the EC2 application security group. There is zero public access to the database layer.
*   **IAM Least-Privilege:** The EC2 instance operates under a strict IAM Role with policies scoped solely to CloudWatch, SSM, and X-Ray requirements.

---

## 💥 Application & Chaos Engineering

The application stack relies on Python, Flask, and systemd. I chose `systemd` to manage the `sre-app`, `prometheus`, and `node-exporter` services to demonstrate fundamental Linux system administration skills, ensuring proper auto-restart behavior and boot persistence.

### Prometheus Instrumentation
The application exposes an internal `/metrics` endpoint instrumented with:
*   `http_requests_total` (Counter) — Segmented by method, endpoint, and status code.
*   `http_request_duration_seconds` (Histogram) — 9 logarithmic buckets ranging from 10ms to 5s.
*   `http_active_requests` (Gauge) — Real-time concurrent request tracking.
*   `db_connections_active` (Gauge) — Monitoring the SQLAlchemy connection pool.

### Chaos Endpoints
*   `/api/orders` — Standard functionality endpoint.
*   `/api/stress` — Actively degrades performance, injecting random 500s (up to 10% failure rate) and simulating CPU spikes to test the SLO burn rate calculations in real-time.

---

## ⚖️ Key Engineering Decisions

1.  **Prometheus over CloudWatch for Core Metrics:** While CloudWatch is great for AWS-native services, Prometheus allowed me to write highly complex, multi-window PromQL recording rules for my SLOs. Offloading this math to Prometheus keeps the alerting logic out of the dashboarding tool (Grafana), adhering to best practices.
2.  **Pull vs. Push Metrics:** Using Node Exporter and Prometheus scraping (Pull) scales much better for internal cluster metrics and prevents the application from being blocked by metric transmission latency. Conversely, I used Push (boto3) specifically for the CloudWatch ML models.
3.  **Monolithic Repo Structure:** I kept the IaC, Application, and Observability configurations in a single repository for demonstration purposes, though in a production setting, these would likely be segmented.

---

## 📈 What I Learned

*   **The Math Behind Reliability:** Implementing Google's SLO math was an eye-opener. Calculating error budget consumption rates based on a 730-hour month and tuning the `14x` and `6x` burn rate thresholds taught me how to quantitatively balance feature velocity against reliability.
*   **Alert Fatigue is the Enemy:** In my first iteration, I alerted on raw CPU and latency spikes. It was noisy and unhelpful. Moving to Error Budgets completely transformed the signal-to-noise ratio of the platform.
*   **Terraform State Management:** Managing 25 resources across 5 modules reinforced the necessity of remote state, careful `depends_on` chaining, and utilizing `outputs.tf` to pass subnet IDs and security groups between isolated modules.

---

## 🚀 Setup & Deployment Instructions

### Prerequisites
*   AWS CLI configured (`~/.aws/credentials`)
*   Terraform `>= 1.7`
*   Python `3.9+`

### 1. Provision Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```
*Note: You must define variables in `terraform.tfvars` (e.g., `db_password`, `my_ip` for SSH, and `alert_email`).*

### 2. Configure the Application
Once Terraform completes, grab the EC2 Public IP from the outputs and SSH in:
```bash
ssh -i sre-platform-key.pem ec2-user@<EC2_PUBLIC_IP>
```
Enable and start the systemd services:
```bash
sudo systemctl daemon-reload
sudo systemctl enable sre-app prometheus node-exporter
sudo systemctl start sre-app prometheus node-exporter
```

### 3. Verify & Break Things
*   **Health Check:** `curl http://localhost:5000/health`
*   **Prometheus:** Available on port `9090`.
*   **Trigger an Incident:** Fire the chaos endpoint to watch the SLO burn rate spike:
    ```bash
    curl -X POST http://localhost:5000/api/stress
    ```

---

## 📂 Part of a 5-Project SRE Portfolio

This project is **Project 1** in a 5-part portfolio meticulously designed to demonstrate readiness for a Senior SRE role at a top-tier tech company.

1.  👉 **Intelligent Observability & SRE Platform:** (This Repository) Infrastructure, telemetry, and the SLO engine.
2.  **Kubernetes Chaos & Resilience:** Containerizing this stack, migrating to Amazon EKS, and implementing automated chaos engineering with Litmus.
3.  **AI-Powered Self-Healing System:** Expanding the AIOps Lambda loop to automatically remediate complex incidents without human intervention.
4.  **Global Traffic Routing & CDN:** Implementing multi-region active-active failover, latency-based routing, and edge caching.
5.  **Zero-Trust Security & Policy-as-Code:** Securing the CI/CD supply chain with OPA, Trivy, and strict Kubernetes RBAC.

*If you are an engineering manager or technical recruiter building out high-performing reliability teams, I am actively interviewing for full-time SRE roles and would love to connect.*

---
**Author:** K A Thejas

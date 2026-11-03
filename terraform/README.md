# Production-Grade AWS Just-In-Time (JIT) Access Management System

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4.svg?logo=terraform)](https://www.terraform.io)
[![AWS](https://img.shields.io/badge/AWS-IAM%20Identity%20Center-FF9900.svg?logo=amazon-aws)](https://aws.amazon.com/iam/identity-center/)
[![Runtime](https://img.shields.io/badge/Runtime-Python%203.12-3776AB.svg?logo=python)](https://www.python.org)
[![Compliance](https://img.shields.io/badge/Compliance-SOC2%20%7C%20ISO27001%20%7C%20CIS-success)](https://aws.amazon.com/compliance/)

A production-grade, enterprise-ready Infrastructure-as-Code (Terraform) implementation of a **Just-In-Time (JIT) Access Management System** on AWS using **AWS IAM Identity Center (formerly AWS SSO)**, **AWS Lambda**, **Amazon DynamoDB**, **Amazon EventBridge Scheduler**, and **Amazon SNS**.

Inspired by the security architecture detailed in [Davebhargavi's article: *Building a Just-In-Time (JIT) Access Management System on AWS Using IAM Identity Center, Lambda, and DynamoDB*](https://medium.com/@davebhargavi507/%EF%B8%8F-building-a-just-in-time-jit-access-management-system-on-aws-using-iam-identity-center-6607886fbb44).

---

## 1. Architectural Overview

Standing privileges (e.g., permanent `AdministratorAccess` or `PowerUserAccess` assigned to developer accounts "just in case") represent one of the most critical attack surfaces in cloud environments. A compromised credential with standing admin rights gives adversaries immediate, unfettered access.

This solution enforces the **Principle of Least Privilege (PoLP)** and **Zero Standing Privileges (ZSP)**:
- Users maintain baseline, low-privilege access by default.
- Elevated multi-account access is provisioned **only when requested with business justification** and approved by designated administrators.
- Access is strictly time-bounded (e.g. 1 to 8 hours).
- Expiration and revocation are **100% automated** via EventBridge Scheduler and verified by a fail-safe reconciliation sweeper.
- Every state change is logged in DynamoDB, SNS, and CloudWatch for SOC 2, ISO 27001, and CIS compliance auditing.

### Architecture Diagram

```text
                               +-----------------------------+
                               |     Requester (Engineer)    |
                               +--------------+--------------+
                                              |
                                              | 1. POST /requests
                                              v
+-----------------------------------------------------------------------------------------+
|                                  Amazon API Gateway (HTTP)                              |
+-------+-----------------------------+-----------------------------+---------------------+
        |                             |                             |
        | 1. Submit Request           | 3. POST /requests/{id}/     | 5. (Optional) Manual
        |                             |    approve OR reject        |    POST /requests/{id}/
        v                             v                             |    revoke
+---------------+             +---------------+                     v
|    Request    |             |   Approval    |             +---------------+
|    Handler    |             |    Handler    |             |  Revocation   |
| (Lambda Py312)|             | (Lambda Py312)|             |    Handler    |
+-------+-------+             +---+-------+---+             | (Lambda Py312)|
        |                         |       |                 +---+-------+---+
        | Saves PENDING           |       |                     ^       ^
        |                         |       | Provisions Access   |       |
        v                         |       v                     |       |
+---------------+                 |   +-----------------------+ |       |
|   DynamoDB    |<----------------+   | AWS IAM Identity Ctr  | |       |
| JITRequests   |  Updates ACTIVE     |  (SSO Admin Service)  | |       |
| Table & GSIs  |                     |  CreateAccountAssign  | |       |
+---------------+                     +-----------------------+ |       |
        |                                                       |       |
        | Publishes Alert                                       |       |
        v                                                       |       |
+---------------+                                               |       |
|   Amazon SNS  |                                               |       |
| Notifications |                                               |       |
+-------+-------+                                               |       |
        |                                                       |       |
        | Email / Slack Alert                                   |       |
        v                                                       |       |
+---------------+                                               |       |
| Security Lead | -- 2. Reviews & Approves                      |       |
+---------------+                                               |       |
                                                                |       |
        +-------------------------------------------------------+       |
        | 4. At ExpiryTime (e.g. +2h)                                   |
        |    EventBridge Scheduler invokes revocation                   |
+-------+---------------------+                                         |
|  EventBridge Scheduler      |                                         |
|  (One-Time Per-Request)     |                                         |
+-----------------------------+                                         |
                                                                        |
+-----------------------------+                                         |
|  EventBridge Sweeper Rule   | 6. Every 5m reconciliation sweeper -----+
|  (Periodic Safety Net)      |    checks overdue ACTIVE sessions
+-----------------------------+
```

---

## 2. Key Components & Production Features

| Component | Resource | Description & Production Safeguards |
| :--- | :--- | :--- |
| **KMS** | `aws_kms_key` | Customer Managed Key (CMK) with annual rotation enabled, encrypting DynamoDB, SNS, CloudWatch Logs, and Lambda DLQ. |
| **DynamoDB** | `aws_dynamodb_table` | Table `JITAccessRequests` with Hash Key `RequestID`, Point-in-Time Recovery (PITR), DynamoDB Streams, TTL auto-pruning, and 2 GSIs (`Status-ExpiryTime-Index`, `Username-RequestedTime-Index`). |
| **Lambda** | `aws_lambda_function` | 3 micro-functions in Python 3.12 (ARM64 Graviton2) with active X-Ray tracing, Dead Letter Queue (SQS), CloudWatch log retention, and strict input validation. |
| **Scheduler** | `aws_scheduler_schedule` | Amazon EventBridge Scheduler schedule group creating millisecond-precise one-time execution timers that auto-delete after completion (`ActionAfterCompletion='DELETE'`). |
| **Sweeper** | `aws_cloudwatch_event_rule` | Cron/rate rule running every 5 minutes as a safety net to reconcile and clean up any missed or orphaned active sessions. |
| **API Gateway**| `aws_apigatewayv2_api` | High-performance HTTP API (v2) with CORS, throttling limits (rate & burst), and structured JSON access logging. |
| **Notifications** | `aws_sns_topic` | Encrypted SNS topic alerting approvers upon request submission, and notifying requesters on approval, rejection, or revocation. |
| **IAM & SSO** | `aws_iam_role` & SSO | Strict least-privilege policies, separation of duties enforcement, and native IAM Identity Center (`sso-admin`) integration. |

---

## 3. Directory Structure

```text
terraform/
├── main.tf                     # Root orchestration module
├── variables.tf                # Input variables with validation rules
├── outputs.tf                  # Outputs with copy-paste curl command templates
├── provider.tf                 # Terraform & AWS provider configuration
├── terraform.tfvars.example    # Documented configuration template
├── terraform.tfvars            # Ready-to-use variable definitions
├── README.md                   # Complete operational and API documentation
└── modules/
    ├── kms/                    # KMS CMK with multi-service key policy
    ├── dynamodb/               # DynamoDB table with GSIs, PITR, TTL, and encryption
    ├── sns/                    # Encrypted SNS topic with email subscriptions
    ├── iam/                    # Least-privilege IAM roles for Lambda & Scheduler
    ├── lambda/                 # Python 3.12 handlers, DLQs, CloudWatch Log Groups
    │   └── src/
    │       ├── common/         # Shared utilities (db, sso, notifier, scheduler, config)
    │       ├── request_handler/# Ingestion & validation of access requests
    │       ├── approval_handler/# SSO assignment provisioning & Scheduler setup
    │       └── revocation_handler/# SSO assignment deprovisioning & Sweeper
    ├── eventbridge/            # Scheduler schedule group & periodic sweeper rule
    ├── api_gateway/            # HTTP API v2 routes, stage, throttling, CORS
    └── identity_center/        # Identity Center auto-discovery & sample permission sets
```

---

## 4. Prerequisites

1. **Terraform**: `>= 1.5.0`
2. **AWS CLI**: `>= 2.0` configured with appropriate administrative credentials.
3. **AWS IAM Identity Center (AWS SSO)**:
   - IAM Identity Center enabled in your AWS Organization (usually in the management account or delegated administrator account).
   - Target AWS account IDs within your AWS Organization.
   - At least one active Permission Set (e.g., `AdministratorAccess`, `ViewOnlyAccess`).

---

## 5. Deployment Instructions

### Step 1: Clone Repository & Change Directory
```bash
cd /home/shiv/mohit/aws-jit-access-manager/terraform
```

### Step 2: Configure Variables
Copy `terraform.tfvars.example` to `terraform.tfvars` (or customize the existing `terraform.tfvars`):
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your target settings:
```hcl
aws_region          = "us-east-1"
environment         = "prod"
project_name        = "jit-access-manager"
notification_emails = ["security-alerts@yourcompany.com"]
max_duration_hours  = 8
```

> **Note on IAM Identity Center Auto-Discovery:**
> By default, the `identity_center` module automatically queries `data.aws_ssoadmin_instances` in the current AWS account. If you want to supply an explicit Instance ARN and Identity Store ID, set `sso_instance_arn` and `identity_store_id` in `terraform.tfvars`.

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Validate Configuration
```bash
terraform validate
```

### Step 5: Review Plan & Apply
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

Upon completion, Terraform will output the API Gateway base URL, DynamoDB table ARN, SNS topic ARN, and sample `curl` commands.

---

## 6. API Reference

### 1. Submit Access Request
* **Endpoint:** `POST /requests`
* **Headers:** `Content-Type: application/json`
* **Request Body:**
```json
{
  "username": "alice.engineer",
  "target_account_id": "112233445566",
  "permission_set_arn": "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-abcdef0123456789",
  "duration_hours": 2,
  "reason": "Investigating high error rate on production payment-service (Incident INC-4091)"
}
```
* **Response:** `201 Created`
```json
{
  "message": "JIT access request submitted successfully. Awaiting approval.",
  "request": {
    "RequestID": "jit-98fa20cb12",
    "Username": "alice.engineer",
    "UserId": "a1b2c3d4-e5f6-7890-abcd-111111111111",
    "TargetAccountID": "112233445566",
    "PermissionSetArn": "arn:aws:sso:::permissionSet/ssoins-1234567890abcdef/ps-abcdef0123456789",
    "DurationHours": 2,
    "Reason": "Investigating high error rate on production payment-service (Incident INC-4091)",
    "Status": "PENDING",
    "RequestedTime": "2026-11-03T08:30:00.000000+00:00",
    "ExpiryTime": 1793699400,
    "ExpiryTimeISO": "2026-11-03T10:30:00",
    "TTL": 1796291400
  }
}
```

---

### 2. List Access Requests
* **Endpoint:** `GET /requests`
* **Query Parameters:**
  - `status`: Filter by status (`PENDING`, `ACTIVE`, `REJECTED`, `EXPIRED`, `REVOKED`)
  - `username`: Filter by username
  - `limit`: Maximum items to return (default 50)
* **Example:** `GET /requests?status=PENDING`
* **Response:** `200 OK`
```json
{
  "count": 1,
  "requests": [
    {
      "RequestID": "jit-98fa20cb12",
      "Username": "alice.engineer",
      "TargetAccountID": "112233445566",
      "Status": "PENDING",
      "DurationHours": 2
    }
  ]
}
```

---

### 3. Get Single Request Details
* **Endpoint:** `GET /requests/{id}`
* **Example:** `GET /requests/jit-98fa20cb12`
* **Response:** `200 OK`

---

### 4. Approve Access Request
* **Endpoint:** `POST /requests/{id}/approve`
* **Headers:** `Content-Type: application/json`
* **Request Body:**
```json
{
  "approver": "secops.lead",
  "notes": "Verified INC-4091 ticket. Approved 2-hour window."
}
```
* **Separation of Duties:** If `approver` matches `Username`, the API returns `403 Forbidden` (`Requester cannot self-approve`).
* **Actions Executed:**
  1. Calls AWS IAM Identity Center `CreateAccountAssignment`.
  2. Dynamically creates EventBridge Scheduler one-time schedule at `ExpiryTimeISO`.
  3. Updates DynamoDB status to `ACTIVE`.
  4. Publishes approval confirmation notification via SNS.
* **Response:** `200 OK`
```json
{
  "message": "Request 'jit-98fa20cb12' approved. Access granted until 2026-11-03T10:30:00 UTC.",
  "request": {
    "RequestID": "jit-98fa20cb12",
    "Status": "ACTIVE",
    "Approver": "secops.lead",
    "ApprovedTime": "2026-11-03T08:30:15.000000+00:00",
    "ActiveUntil": "2026-11-03T10:30:15 UTC",
    "ScheduleName": "jit-expire-jit-98fa20cb12"
  }
}
```

---

### 5. Reject Access Request
* **Endpoint:** `POST /requests/{id}/reject`
* **Headers:** `Content-Type: application/json`
* **Request Body:**
```json
{
  "approver": "secops.lead",
  "reason": "Target account maintenance window in progress. Re-submit after 12:00 UTC."
}
```
* **Response:** `200 OK`

---

### 6. Emergency / Manual Early Revocation
* **Endpoint:** `POST /requests/{id}/revoke`
* **Headers:** `Content-Type: application/json`
* **Request Body:**
```json
{
  "reason": "Incident resolved early by engineering team."
}
```
* **Actions Executed:**
  1. Calls AWS IAM Identity Center `DeleteAccountAssignment`.
  2. Deletes pending EventBridge Scheduler timer.
  3. Updates DynamoDB status to `REVOKED`.
  4. Sends SNS notification.
* **Response:** `200 OK`

---

## 7. Dual Expiration Guarantee (EventBridge Scheduler + Sweeper)

To ensure zero risk of lingering administrative access, the system uses a **dual-layer expiration architecture**:

1. **Layer 1 (Event-Driven Scheduler):**
   When a request is approved, the system creates a one-time schedule in **Amazon EventBridge Scheduler** targeted at the exact second the session expires (`at(YYYY-MM-DDTHH:MM:SS)`).
   - Precision: Exactly on time.
   - Self-Cleaning: Configured with `ActionAfterCompletion='DELETE'`.

2. **Layer 2 (Reconciliation Sweeper):**
   An **Amazon EventBridge Rule** triggers the revocation Lambda every 5 minutes (`rate(5 minutes)`).
   - Scans the `Status-ExpiryTime-Index` for any `Status = 'ACTIVE'` records where `ExpiryTime <= CurrentEpoch`.
   - If any expired sessions are found (e.g. in case of schedule deletion or network glitch), the sweeper immediately deletes the account assignment and marks the record `EXPIRED`.
   - Result: 100% fail-safe guarantee against orphaned permissions.

---

## 8. Security & Compliance Checklist

- [x] **Zero Standing Privileges:** Eliminates permanent elevated account assignments.
- [x] **Separation of Duties (SoD):** Requesters are blocked from self-approving their own requests.
- [x] **KMS CMK Encryption:** All data at rest (DynamoDB, SNS, CloudWatch Logs, SQS DLQ) encrypted with customer managed key with key rotation enabled.
- [x] **Point-in-Time Recovery (PITR):** Enabled on DynamoDB for disaster recovery.
- [x] **Dead Letter Queue (DLQ):** SQS DLQ attached to all Lambda functions for error handling and observability.
- [x] **Audit Trail Retention:** Expired records retained in DynamoDB for 30 days before TTL cleanup; CloudWatch logs retained for 30 days.
- [x] **API Rate Limiting:** Default throttling limits configured on API Gateway to prevent DoS.
- [x] **Least Privilege IAM:** Scoped IAM roles per function; no wildcard `*` permissions on data access.

---

## 9. Cleanup & Teardown

To destroy all deployed resources when no longer needed:

```bash
terraform destroy
```

> [!WARNING]
> Ensure that all active JIT assignments have been revoked before running `terraform destroy` so that IAM Identity Center account assignments are cleanly stripped.


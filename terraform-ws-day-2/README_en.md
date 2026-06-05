# DEVK Terraform Workshop – Day 2

Today you will build the backend of a claims portal. Policyholders can file claims online, upload documents, and check the status.

By the end of the day you will have:
- Implemented a storage module in Terraform and deployed it to S3
- Implemented a PostgreSQL database in Terraform and deployed it to RDS
- Provisioned two Lambda functions via Terraform
- Set up an API Gateway with three REST endpoints

---

## Use Case: Claims Portal

```
                   ① POST /claims    ┌──────────────────┐
   ┌─────────┐ ──────────────────►  │   API Gateway    │
   │ Browser │                      │   + API Lambda   │──── ② INSERT ────► ┌──────────────┐
   └────┬────┘ ◄──────────────────  │                  │                    │ RDS Postgres │
        │        ③ { upload_url }   └──────────────────┘                    └──────▲───────┘
        │                                                                           │
        │ ④ PUT (presigned URL)     ┌──────────┐   ⑤ ObjectCreated   ┌────────────┴────────┐
        └──────────────────────────►│    S3    │──────────────────►  │  Processor Lambda   │
                                    └──────────┘                      └─────────────────────┘
```

---

## Relation to Day 1

Today you apply the same concepts as yesterday — with more services and a real application:

| Day 1 | Day 2 |
|-------|-------|
| Simple S3 resources | S3 with versioning, encryption, lifecycle |
| Built one custom module | Implement a module yourself + use pre-built modules |
| Provider, variables, outputs | All of that — plus IAM, Lambda, RDS, API Gateway |

---

## AWS Services Today

| Service | What does it do? | Terraform resource |
|---------|------------------|--------------------|
| **S3** | Object storage, infinitely scalable | `aws_s3_bucket` |
| **RDS** | Managed relational database | `aws_db_instance` |
| **Lambda** | Run code without servers, event-triggered | `aws_lambda_function` |
| **API Gateway** | Manage HTTP API endpoints | `aws_apigatewayv2_api` |

---

## Setup

Work through all four steps in order. If something doesn't work, ask before continuing.

> **Important:** Run `terraform destroy` at the end of the workshop — otherwise RDS keeps running and incurs costs.

---

### Step 1 – Set AWS credentials

Environment variables from Day 1 are gone after closing the terminal. Set them again in every new terminal window — you already have your access key from Day 1.

macOS / Linux:
```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=eu-central-1
```

Windows (PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION = "eu-central-1"
```

> If you get unexplained authentication errors later: this is usually the first place to check.

If you no longer have your access key: open the AWS Console → click your username in the top right → **Security credentials** → **Create access key**.

**Verify:**

```bash
aws sts get-caller-identity
```

The command must return an account ID. An error message means the credentials are not set correctly.

---

### Step 2 – Check for a default VPC

RDS requires a subnet group that covers at least two availability zones. We use the default VPC for this, which should be present in every AWS account.

**Verify:**

```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text \
  --region eu-central-1
```

You should see a VPC ID, e.g. `vpc-0a1b2c3d`. If the output is `None`:

```bash
aws ec2 create-default-vpc
```

---

### Step 3 – Set the database password

`terraform.tfvars` contains your personal input values for Terraform — including the password for the RDS database you create in Part 1.

Copy the example file and create your `terraform.tfvars` from it:

macOS / Linux:
```bash
cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

Windows (PowerShell):
```powershell
Copy-Item envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

Open `envs/dev/terraform.tfvars` in your editor and replace `PleaseSetAStrongPasswordHere!` with your own password. The file is in `.gitignore` — it will never be checked into the repository.

> **Important:** Search `envs/dev/main.tf` and all modules (`modules/storage/main.tf`, `modules/database/main.tf`, `modules/processor/main.tf`, `modules/api/main.tf`) for the placeholder `FIRSTNAME` and replace it with your first name (e.g. `anna`). This ensures that your resources get unique names and don't conflict with those of other participants.

Also install the Python dependencies for the Lambda functions:

```bash
pip3 install -r lambda-src/processor/requirements.txt -t lambda-src/processor/
pip3 install -r lambda-src/api/requirements.txt -t lambda-src/api/
```

**Verify:** The placeholder is replaced with your own password, `FIRSTNAME` is replaced with your first name, and the dependencies were installed.

---

### Step 4 – Initialize Terraform

Switch to the `envs/dev/` directory and download the provider plugins and register the modules:

```bash
cd terraform-ws-day-2/envs/dev
terraform init
```

You should see: `Terraform has been successfully initialized!` You are now ready to start the tasks.

---

## Overview: What is pre-built, what do you implement?

```
modules/
├── storage/     ← YOU implement main.tf       (Task Part 1)
├── database/    ← YOU implement main.tf       (Task Part 1)
├── processor/   ← pre-built, S3 trigger as TODO (Task Part 2)
└── api/         ← YOU implement main.tf       (Task Part 2)

envs/dev/
├── main.tf      ← YOU fill in TODO A–D step by step
└── outputs.tf   ← Outputs are uncommented step by step
```

**Your workflow for each step:**

```
Write .tf file  →  terraform plan  →  terraform apply
```

Run `terraform plan` after each new resource. This way you catch errors early and understand what Terraform intends to do.

---

## Part 1: Storage Module + Database

### Step 1.1 – Implement the storage module

**Goal:** Implement `modules/storage/main.tf`. The module should create an S3 bucket with versioning, server-side encryption, and a public access block — as required by a claims portal.

Yesterday you already built S3 resources. Today you go one step further: versioning, encryption, and lifecycle.

**Requirements:**

| # | What                                                           | Why |
|---|---------------------------------------------------------------|-----|
| 1 | S3 bucket named `{project}-{environment}-claims-{FIRSTNAME}` | Unique name in the global S3 namespace |
| 2 | Enable versioning                                             | Documents must not be lost |
| 3 | Encryption with AES256                                        | Encrypt data at rest (GDPR) |
| 4 | Public access block (all 4 flags = true)                      | Bucket must never be publicly accessible |
| 5 | Lifecycle rule (bonus)                                        | Delete old versions after 90 days |

**Where to start:**

1. Open `modules/storage/variables.tf` — what is available to you?
2. Open `modules/storage/outputs.tf` — what should the module expose?
3. Implement `modules/storage/main.tf` resource by resource

```bash
# After each newly initialized module:
terraform init
# Test after each new resource:
terraform plan -target=module.storage
```

> Solution if needed: `solutions/storage/main.tf`

<details>
<summary>Hint – Resource 1: S3 bucket</summary>

`aws_s3_bucket` needs a `bucket` argument for the name. Bucket names must be globally unique — build it from the variables available to you: `var.project`, `var.environment`, and `var.suffix`. Terraform string interpolation works like this: `"${var.project}-additional-text"`. Also set `tags = var.tags`.

Look in `variables.tf` for which variables the module receives — you don't need to hard-code anything.

</details>

<details>
<summary>Hint – Resource 2: Versioning</summary>

`aws_s3_bucket_versioning` needs a `bucket` argument — reference your bucket with `aws_s3_bucket.claims.id` (not a hard-coded name, but a resource reference). This is the same pattern as in Day 1.

Inside the block comes a `versioning_configuration` block with a `status` argument. What value must `status` have for versioning to be active?

</details>

<details>
<summary>Hint – Resource 3: Encryption</summary>

`aws_s3_bucket_server_side_encryption_configuration` has a nested structure — this is common with AWS resources in Terraform. The structure: a `rule` block, inside it an `apply_server_side_encryption_by_default` block, inside it the `sse_algorithm` argument.

The value for server-side encryption without custom keys is `"AES256"`.

</details>

<details>
<summary>Hint – Resource 4: Public access block</summary>

`aws_s3_bucket_public_access_block` has four boolean arguments, each controlling a different aspect of public access:

- `block_public_acls`
- `block_public_policy`
- `ignore_public_acls`
- `restrict_public_buckets`

All four should be `true`. This is the secure configuration for a bucket that should never be publicly accessible — in contrast to Day 1, where you opened up public access.

</details>

<details>
<summary>Hint – Resource 5 (bonus): Lifecycle rule</summary>

`aws_s3_bucket_lifecycle_configuration` needs a `rule` block with three parts:
- `id` — an arbitrary name for the rule
- `status = "Enabled"` — to make the rule active
- a `noncurrent_version_expiration` block with the argument `noncurrent_days`

`noncurrent_version_expiration` only acts on older versions of an object — the current version is not affected. The `noncurrent_days` argument specifies after how many days old versions are automatically deleted.

</details>

**Terraform documentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration

---

### Step 1.2 – Deploy and test storage

**Goal:** Integrate the storage module in `envs/dev/main.tf` (TODO A) and deploy it.

Open `envs/dev/main.tf` — there you will find the commented-out TODO-A block. Uncomment it and look at which arguments are passed. Also look at `modules/storage/outputs.tf`: which values does the module return? These will be needed later by `processor` and `api`.

<details>
<summary>Hint – Calling a module</summary>

A `module` block in Terraform works like a function call: `source` gives the path to the module, the remaining arguments correspond to the `variable` declarations in `modules/storage/variables.tf`. Look at which variables the module expects — and which values from the calling context (`var.*`, `local.*`, `resource.*`) you can pass.

</details>

```bash
terraform init
terraform apply -target=module.storage
```

**Verify:**

```bash
BUCKET=$(terraform output -raw s3_bucket)

# Test upload
echo "Test document" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://${BUCKET}/policies/POL-99999/test.txt
aws s3 ls s3://${BUCKET}/policies/POL-99999/

# Check versioning
aws s3api get-bucket-versioning --bucket ${BUCKET}
# Expected: { "Status": "Enabled" }
```

> `-target` is normally a code smell. We use it today deliberately to build up the infrastructure step by step. In everyday use: `terraform apply` without `-target`.

---

### Step 1.3 – Implement the database module

**Goal:** Implement `modules/database/main.tf`. The module should create a PostgreSQL database on RDS — with a subnet group, a security group (both as data sources), and the RDS instance itself.

> **Note:** The following resources were pre-created by the admin — you reference them via `data` blocks instead of creating them yourself. This is an important Terraform concept: integrating existing infrastructure without managing it:
> - DB subnet group `devk-dev-claims` (spans all default subnets)
> - Security group `devk-dev-rds` (port 5432)

**Requirements:**

| # | What | Resource |
|---|------|----------|
| 1 | Reference existing DB subnet group | `data "aws_db_subnet_group"` |
| 2 | Reference existing security group | `data "aws_security_group"` |
| 3 | PostgreSQL RDS instance (db.t3.micro, 20 GB) | `aws_db_instance` |

**Where to start:**

1. Open `modules/database/variables.tf` — what variables are available?
2. Open `modules/database/outputs.tf` — what should the module return?
3. Implement the three resources in order


<details>
<summary>Hint – Resource 1: DB subnet group as a data source</summary>

With `data "aws_db_subnet_group"` you reference an already existing subnet group — Terraform creates nothing, it only reads the name. This is the same principle as for the security group.

The block only needs `name` to find it. You can compose the name from `var.project` and `var.environment` (pattern: `{project}-{environment}-claims`).

Then reference the name like this: `data.aws_db_subnet_group.claims.name`

</details>

<details>
<summary>Hint – Resource 2: Security group as a data source</summary>

With `data "aws_security_group"` you reference an already existing security group without managing it yourself. The difference from `resource`: Terraform creates nothing, it only reads the ID.

The block needs `name` and `vpc_id` to find the SG. You can compose the name from `var.project` and `var.environment` (pattern: `{project}-{environment}-rds`). The VPC ID comes from `var.vpc_id`.

Then reference the ID like this: `data.aws_security_group.rds.id`

</details>

<details>
<summary>Hint – Resource 3: RDS instance</summary>

`aws_db_instance` has many arguments — these are the important ones for the workshop:
- `identifier` — unique name of the instance (pattern: `{project}-{environment}-claims-FIRSTNAME`)
- `engine = "postgres"`, `engine_version = "16.6"`
- `instance_class = "db.t3.micro"`, `allocated_storage = 20`
- `storage_encrypted = true`
- `db_name`, `username`, `password` — from the variables
- `db_subnet_group_name` — name of the subnet group (data reference)
- `vpc_security_group_ids` — list with the SG ID from the data block
- `publicly_accessible = true` — workshop simplification
- `skip_final_snapshot = true`, `backup_retention_period = 0`, `deletion_protection = false` — workshop only

</details>

**Terraform documentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_subnet_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance


```bash
terraform plan -target=module.database
```
---

### Step 1.4 – Deploy the database

**Goal:** Integrate the database module in `envs/dev/main.tf` and `envs/dev/outputs.tf` (TODO B) and deploy it.

> **Note:** The following resources were pre-created by the admin — Terraform finds them by name, you don't need to create anything:
> - DB subnet group `devk-dev-claims` (for RDS)
> - Security group `devk-dev-rds` (port 5432, for RDS)
> - IAM role `devk-dev-processor-role` (for the processor Lambda)
> - IAM role `devk-dev-api-role` (for the API Lambda)

```bash
terraform init
terraform apply -target=module.database
```

This takes about 8–10 minutes. Use the time for the discussion points below.

**Verify:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier devk-dev-claims-FIRSTNAME \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text \
  --region eu-central-1
```

Expected output: `available`

**Discussion points during the wait:**
- Why `skip_final_snapshot = true`? (When is this dangerous?)
- Why is `db_password` marked as `sensitive = true`?
- `publicly_accessible = true` — why is this a simplification here, and what would it look like in production?
- What is a subnet group and why does RDS need it?

---

## Part 2: Deploy and Understand the Application Layer

### Step 2.1 – Guided tour: Processor module

**Goal:** Understand how Lambda is provisioned via Terraform and how S3 events work.

Read `modules/processor/main.tf` together. The file has five parts:

**1. `data "archive_file"`** — zipping the source code
Terraform zips the Python code on-the-fly directly from the source directory. `source_code_hash` ensures that Lambda is automatically redeployed with every code change — without this hash, Terraform would not detect the change.

**2. `data "aws_iam_role"`** — looking up the IAM role
The role was pre-created by the admin (participants don't have `iam:CreateRole` permission). Terraform reads it here by name — a typical pattern for integrating existing infrastructure without managing it.

**3. `aws_cloudwatch_log_group`** — explicitly managing logs
Lambda automatically creates a log group — but then Terraform has no control over it. By managing it explicitly, the retention can be set to 7 days and the log group is cleanly deleted on `terraform destroy`.

**4. `aws_lambda_function`** — the function itself
Links all previous parts: zipped code, IAM role, environment variables for DB and S3. `depends_on` ensures the log group exists first before Lambda is deployed.

**5. TODO: `aws_lambda_permission` + `aws_s3_bucket_notification`** — S3 trigger
These two resources are not yet implemented — that is your task in step 2.2.

Also look at `lambda-src/processor/handler.py` — what does the code actually do?

---

### Step 2.2 – Implement and deploy the S3 trigger

**Goal:** Implement the S3 trigger yourself — two resources that together establish the event flow — and deploy the processor Lambda.

Open `modules/processor/main.tf` and implement the TODO block at the end.

**Requirements:**

| # | Resource | What it does |
|---|----------|--------------|
| 1 | `aws_lambda_permission` | Allows S3 to invoke the Lambda |
| 2 | `aws_s3_bucket_notification` | Triggers the Lambda on every upload |

<details>
<summary>Hint – S3 trigger: two resources, one concept</summary>

AWS intentionally separates permission and configuration:

**`aws_lambda_permission`** is an IAM-like permission at the Lambda function level itself. Without it, S3 would get an `Access Denied` when calling — even if the bucket notification is configured correctly. Relevant arguments: `action`, `function_name`, `principal`, `source_arn`.

**`aws_s3_bucket_notification`** configures the bucket so that it activates on certain events. The inner `lambda_function` block needs `lambda_function_arn` and `events`. For "every new object" the event is `s3:ObjectCreated:*`.

Important: `aws_s3_bucket_notification` must have a `depends_on` on `aws_lambda_permission` — otherwise Terraform tries to set the notification before the permission exists.

</details>

**Terraform documentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification


Then open `envs/dev/main.tf` and `envs/dev/output.tf` and uncomment the TODO-C block:

```hcl
module "processor" {
  source      = "../../modules/processor"
  project     = var.project
  environment = var.environment
  source_dir  = "${path.module}/../../lambda-src/processor"
  bucket_id   = module.storage.bucket_id
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}
```

```hcl
output "processor_log_group" {
  description = "CloudWatch log group of the processor Lambda — for debugging"
  value       = module.processor.log_group_name
}
```

```bash
terraform init
terraform apply -target=module.processor
```

**Verify:**

```bash
# Upload simulates a claim
echo "Damage photo mock" > /tmp/damage.jpg
aws s3 cp /tmp/damage.jpg \
  s3://$(terraform output -raw s3_bucket)/policies/POL-12345/damage.jpg

# Follow Lambda logs live (Ctrl+C to stop)
aws logs tail $(terraform output -raw processor_log_group) --follow --region eu-central-1
```

You should see: Lambda receives the S3 event, creates the table, and writes an entry.

---

### Step 2.3 – Implement the API module

**Goal:** Implement the API module yourself — Lambda function and API Gateway.

Open `modules/api/main.tf`. Two TODO blocks are waiting for you.

**Requirements:**

| # | What | Resource |
|---|------|----------|
| 1 | CloudWatch log group | `aws_cloudwatch_log_group` |
| 2 | Lambda function | `aws_lambda_function` |
| 3 | HTTP API | `aws_apigatewayv2_api` |
| 4 | Lambda integration | `aws_apigatewayv2_integration` |
| 5 | Three routes | `aws_apigatewayv2_route` (×3) |
| 6 | Permission for API Gateway | `aws_lambda_permission` |

Also look at `lambda-src/api/handler.py` — how are routes matched, how is the presigned URL generated?

<details>
<summary>Hint – TODO 1: Lambda function</summary>

The `cloudwatch_log_group` needs `name`, which must be exactly the Lambda function name, `retention_in_days = 7`, and `tags`.

The pattern for the Lambda function is analogous to the processor module. The differences:
- `function_name` ends with `"claims-api"`
- `timeout = 15` (shorter than processor)
- Additional env variable: `BUCKET_NAME = var.bucket_name`

Reference `data.aws_iam_role.api.arn` for the IAM role (already provided).

</details>

<details>
<summary>Hint – TODO 2: API Gateway</summary>

**`aws_apigatewayv2_api`**: Needs `name`, `protocol_type = "HTTP"`, and a `cors_configuration` block (so that browser requests work). Allow origins `["*"]`, methods `["GET", "POST", "OPTIONS"]`, headers `["Content-Type"]`.

**`aws_apigatewayv2_integration`**: Connects the API to the Lambda. `integration_type = "AWS_PROXY"`, `api_id = aws_apigatewayv2_api.claims.id`, `integration_uri` is the `invoke_arn` of the Lambda function, `payload_format_version = "2.0"`.

**`aws_apigatewayv2_route`**: Each route needs the `api_id`, a `route_key` (e.g. `"POST /claims"`), and `target` — the format is `"integrations/${aws_apigatewayv2_integration.lambda.id}"`. Create three routes: `POST /claims`, `GET /claims`, `GET /claims/{id}`.

**`aws_lambda_permission`**: Same pattern as the S3 trigger, but `principal = "apigateway.amazonaws.com"` and `source_arn = "${aws_apigatewayv2_api.claims.execution_arn}/*/*"`.

</details>

**Terraform documentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission


```bash
terraform plan -target=module.api
```

If the plan is clean: integrate the module and enable the outputs.

**`envs/dev/main.tf`** – uncomment the TODO-D block:

```hcl
module "api" {
  source      = "../../modules/api"
  project     = var.project
  environment = var.environment
  source_dir  = "${path.module}/../../lambda-src/api"
  bucket_name = module.storage.bucket_name
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}
```

**`envs/dev/outputs.tf`** – uncomment both API outputs:

```hcl
output "api_url" {
  description = "Base URL of the claims API"
  value       = module.api.api_endpoint
}

output "api_log_group" {
  description = "CloudWatch log group of the API Lambda"
  value       = module.api.log_group_name
}
```

---

### Step 2.4 – Deploy the API

**Goal:** Complete the entire setup.

```bash
terraform init
# Without -target — deploys everything now
terraform apply
```

Print the API URL:

```bash
terraform output -raw api_url
```

If at any point you want to look at the API logs, do this with:
```bash
aws logs tail $(terraform output -raw api_log_group) --follow --region eu-central-1
```

---

### Step 2.5 – End-to-end testing

**Goal:** Walk through the complete claim flow from POST to S3 upload.

```bash
API_URL=$(terraform output -raw api_url)

# Create a claim
curl -s -X POST ${API_URL}/claims \
  -H "Content-Type: application/json" \
  -d '{
    "policy_number": "POL-12345",
    "claim_type":    "motor",
    "description":   "Parking damage in the Aldi car park"
  }' | jq

# List all claims
curl -s ${API_URL}/claims | jq
```

```bash
# Retrieve a single claim (insert ID from the POST response)
curl -s ${API_URL}/claims/CLM-XXXXXXXXXX | jq
```

**Presigned URL – the browser upload flow:**

The POST response contains an `upload_url`. This is an AWS presigned URL — it allows a browser to upload directly to S3 for one hour, without having its own AWS credentials. Look at `lambda-src/api/handler.py` to see how it is generated.

```bash
# Take the presigned URL from the POST response and upload directly with it:
UPLOAD_URL="<upload_url from the POST response>"
curl -X PUT "${UPLOAD_URL}" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/tmp/damage.jpg
```

**Verify:** Check processor logs — was the document registered?

```bash
aws logs tail $(terraform output -raw processor_log_group) --follow --region eu-central-1
```

---

## Cleanup

> **Important:** Please clean up at the end of the workshop — otherwise RDS will incur ongoing costs.

The S3 bucket must be empty before it can be deleted.
To do this, go to the [AWS Console](https://856021348966.signin.aws.amazon.com/console), either under "Recently visited" or under "All services" in "S3", select your bucket (devk-dev-claims-FIRSTNAME), click "Empty", and confirm. Afterwards you can clean up all resources with `terraform destroy`.

```bash
# S3 bucket must be empty, otherwise destroy will fail
terraform destroy
```

---

## Best Practices

What is intentionally simplified in this setup and how to make it production-ready — guide: `docs/best-practices.md`

| Workshop simplification | Production |
|------------------------|-----------|
| `publicly_accessible = true` (RDS) | `false` + Lambda in VPC + private subnets + NAT |
| RDS security group open (0.0.0.0/0) | Security group references to Lambda SGs |
| `db_password` in tfvars | AWS Secrets Manager + `random_password` |
| `skip_final_snapshot = true` | `false` + maintain snapshot name |
| Lambda code in the same repo | Separate pipeline + S3 versioning |
| API without auth | Cognito / API keys / IAM auth |
| Single-AZ RDS | Multi-AZ + read replica |
| Default VPC | Custom VPC with private subnets + NAT |
| No `.terraform.lock.hcl` | Check into git: `terraform providers lock` |

---

## If Something Goes Wrong

See `docs/troubleshooting.md` and `docs/cheatsheet.md`.

Common pitfalls:
- **Default VPC missing**: `aws ec2 create-default-vpc`
- **terraform.tfvars missing**: `cp terraform.tfvars.example terraform.tfvars`

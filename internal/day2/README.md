# Internal AWS Workshop - Day 2

Yesterday you built a feedback portal by clicking. Today you build the same thing again - but this time you describe it in files, and Terraform does the clicking.

By the end of today you will have:
- Written the S3 bucket, the Lambda function and the HTTP API as Terraform code
- Deployed all of it with `terraform apply`, from nothing to a working API
- Changed a running resource by editing a file and reading a plan
- Torn the whole stack down again with a single command

Your Day 1 resources stay untouched the entire time. Today's carry `tf` in their names instead of `manual`, so you can put the two side by side in the console and see that they are identical.

---

## Use Case: Feedback Portal

The same as yesterday. Same three endpoints, same `handler.py`.

```
   ┌──────────┐   ① POST /feedback    ┌─────────────────────┐
   │   curl   │ ────────────────────► │     API Gateway     │
   │    or    │                       │      (HTTP API)     │
   │  browser │ ◄──────────────────── └──────────┬──────────┘
   └──────────┘   ④ { "id": "…" }                │
                                                 │ ② invoke
                                                 ▼
                                      ┌─────────────────────┐
                                      │       Lambda        │
                                      │     handler.py      │
                                      └──────────┬──────────┘
                                                 │
                                                 │ ③ PutObject
                                                 ▼
                                      ┌─────────────────────┐
                                      │         S3          │
                                      │ feedback/<id>.json  │
                                      └─────────────────────┘
```

---

## Relation to Day 1

| | Day 1 | Day 2 |
|---|---|---|
| How you create things | Click through a wizard | Write a resource block |
| Record of what you did | Your memory | A file in git, with a diff and an author |
| Doing it a second time | Click through it again | `terraform apply` in a second directory |
| Undoing it | Delete four things by hand, in the right order | `terraform destroy` |
| Finding out what changed | Compare console screens | `terraform plan` |
| What the settings are | Whatever the defaults were that day | Written down, explicitly |

The infrastructure is identical. What changes is that it becomes reviewable, repeatable and disposable.

---

## Terraform in five minutes

Terraform is an **Infrastructure as Code** tool. You describe the state you want in `.tf` files, and Terraform works out which API calls get reality there.

| Term | Meaning |
|---|---|
| **Resource** | One thing you own - a bucket, a function, a route. Declared with `resource "type" "name" { … }`. Terraform creates, updates and deletes it. |
| **Data source** | One thing that already exists and that you only want to read. Declared with `data "type" "name" { … }`. Terraform never changes it. |
| **Provider** | The plugin that knows how to talk to a platform. `hashicorp/aws` knows AWS. |
| **State** | Terraform's record of which real resource belongs to which block in your code. Today it is a local `terraform.tfstate` file. |
| **Plan** | A dry run. `terraform plan` shows exactly what would change, and changes nothing. |
| **Apply** | `terraform apply` executes the plan, after asking you to confirm. |
| **Variable** | A named input, so the same code can produce your stack and your colleague's. |
| **Output** | A value Terraform prints when it is done - a URL, a bucket name - so you do not have to go looking for it. |

Your loop for every step today:

```
edit a .tf file  →  terraform plan  →  read the output  →  terraform apply
```

Never skip the plan. It costs two seconds and it is the only thing standing between a typo and a deleted resource.

---

## Setup

Work through all four steps in order. If something does not work, ask before moving on.

---

### Step 1 - Install Terraform

macOS / Linux:
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Windows (PowerShell):
```powershell
winget install HashiCorp.Terraform
```

> Close and reopen your terminal after installing.

**Verify:**

```bash
terraform version
```

Must print `v1.6` or newer.

---

### Step 2 - AWS credentials

Terraform uses exactly the same credentials as the AWS CLI. If you set up the `nl-ws` profile yesterday, you only need to point this shell at it:

macOS / Linux:
```bash
export AWS_PROFILE=nl-ws
```

Windows (PowerShell):
```powershell
$env:AWS_PROFILE = "nl-ws"
```

If your SSO session has expired since yesterday - and it has:

```bash
aws sso login --profile nl-ws
```

**Verify:**

```bash
aws sts get-caller-identity
```

Must return account `654654436000`. If it does not, fix it now. Terraform failing on credentials produces far less helpful errors than the CLI does.

<details>
<summary>Hint - you never set up the profile yesterday</summary>

Run `aws configure sso` and answer: session name `nl`, start URL `https://nl.awsapps.com/start/#/`, SSO region `eu-west-1`, account `654654436000`, role `WriteAccess`, default region `eu-west-1`, output `json`, profile name `nl-ws`.

</details>

---

### Step 3 - Your input values

`terraform.tfvars` holds your personal inputs. Copy the example and edit it:

macOS / Linux:
```bash
cd internal/day2/terraform
cp terraform.tfvars.example terraform.tfvars
```

Windows (PowerShell):
```powershell
cd internal/day2/terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and replace `vorname` with your own first name, lowercase:

```hcl
name_suffix = "anna"
```

That one value drives every resource name today. The file is gitignored and never lands in the repository.

**Verify:** `terraform.tfvars` exists and contains your name, not `vorname`.

---

### Step 4 - Initialise Terraform

From `internal/day2/terraform`:

```bash
terraform init
```

This downloads the `aws` and `archive` providers into `.terraform/`.

**Verify:** you see `Terraform has been successfully initialized!`

Then check that your variables are picked up:

```bash
terraform plan
```

Nothing is declared yet, so there is no infrastructure to create - but the `resource_names` output already resolves, and the plan shows it under **Changes to Outputs**. Read those three names: they are what you are about to build, and they must all end in your own first name.

<details>
<summary>Hint - the plan asks for a variable instead of printing anything</summary>

`name_suffix` has no default, so Terraform prompts for it when it cannot find a value. That means `terraform.tfvars` is missing, is in the wrong directory, or still says `vorname`. Go back to Step 3.

</details>

---

## Overview: what is given, what you build

```
internal/day2/
├── lambda-src/api/handler.py    ← given - the same code you pasted yesterday
├── terraform/                   ← your working directory
│   ├── main.tf                  ← given - provider, naming, tags
│   ├── backend.tf               ← given - comments only, read it
│   ├── variables.tf             ← given
│   ├── terraform.tfvars         ← yours, from Step 3
│   ├── s3.tf                    ← YOU implement (Part 1)
│   ├── lambda.tf                ← YOU implement (Part 2)
│   ├── apigateway.tf            ← YOU implement (Part 3)
│   └── outputs.tf               ← given, partly commented out
├── solutions/                   ← the finished files, if you get stuck
└── docs/
    ├── cheatsheet.md            ← commands
    └── best-practices.md        ← what we deliberately did not do
```

Open `main.tf` before you start. It defines `local.bucket_name`, `local.function_name`, `local.api_name`, `local.iam_role_name` and `local.tags` - use those everywhere instead of typing names by hand.

Each of the three files starts with a comment block stating the goal, the requirements and the documentation links. That block is the task.

---

## Commands you will use today

```bash
terraform init                      # download providers, once per directory
terraform fmt                       # reformat your .tf files to the standard style
terraform validate                  # is this syntactically valid and self-consistent?
terraform plan                      # what would change? changes nothing
terraform apply                     # make it so, after confirming with "yes"
terraform apply -target=RESOURCE    # only this one resource (see the note in Part 1)
terraform output                    # show all outputs
terraform output -raw api_url       # one output, unquoted, for use in scripts
terraform state list                # which resources does Terraform think it owns?
terraform show                      # everything it knows about them
terraform destroy                   # delete everything in this configuration
```

More, including the AWS CLI equivalents, in [docs/cheatsheet.md](docs/cheatsheet.md).

---

## Part 1 - Storage

**Goal:** the bucket from Day 1, in code.

Open `s3.tf`. The comment block at the top is your task; the commented-out `resource` stubs below it are your skeleton.

**Requirements:**

| # | What | Why |
|---|---|---|
| 1 | `aws_s3_bucket` named `local.bucket_name`, tagged `local.tags` | The bucket itself |
| 2 | `aws_s3_bucket_versioning`, status enabled | You ticked this box yesterday |
| 3 | `aws_s3_bucket_server_side_encryption_configuration`, `AES256` | You left this on its default yesterday - here it is explicit |
| 4 | `aws_s3_bucket_public_access_block`, all four flags `true` | Also a default yesterday. Defaults change; code does not |

**Where to start:**

1. Read `main.tf` and find the local value that holds the bucket name.
2. Write requirement 1 only, then run `terraform plan`.
3. Add the next resource, plan again. One at a time.

<details>
<summary>Hint - resource 1: the bucket</summary>

`aws_s3_bucket` needs surprisingly little: which attribute holds the name? Look at the argument reference in the docs - there is exactly one required argument.

Tags go on as `tags = local.tags`.

</details>

<details>
<summary>Hint - resources 2-4: why are these separate?</summary>

Yesterday versioning and encryption looked like checkboxes on the bucket form. In the AWS API they are separate calls against an existing bucket, and the Terraform provider mirrors the API rather than the console.

All three take a `bucket` argument. What should it refer to? You want Terraform to create the bucket *first* and then configure it - so point at the bucket resource's attribute, not at the name string. That reference is what tells Terraform the order.

</details>

<details>
<summary>Hint - the nested blocks</summary>

Two of these three need a nested block, not a plain argument:

- versioning wraps its setting in `versioning_configuration { … }` - and the value it wants is a capitalised word, not `true`
- encryption nests twice: `rule { apply_server_side_encryption_by_default { … } }`

The public access block is flat: four boolean arguments, no nesting.

</details>

**Terraform documentation:**

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block

> Solution if you need it: [solutions/s3.tf](solutions/s3.tf)

### Deploy it

```bash
terraform fmt
terraform plan
terraform apply
```

Read the plan before typing `yes`. Four resources to add, nothing to change, nothing to destroy.

Then uncomment the `bucket_name` output in `outputs.tf` and run `terraform apply` again - outputs are part of the state, so they need an apply to show up.

**Verify:**

```bash
BUCKET=$(terraform output -raw bucket_name)
aws s3api get-bucket-versioning --bucket "$BUCKET"
# Expected: { "Status": "Enabled" }

aws s3api get-public-access-block --bucket "$BUCKET"
# Expected: all four flags true
```

> `terraform apply -target=aws_s3_bucket.feedback` limits an apply to one resource. It is useful while you are building things up step by step, and it is a code smell everywhere else - it applies a configuration you never fully planned. We use it deliberately today; in real work, run `terraform apply` without it.

---

## Part 2 - Compute

**Goal:** package `lambda-src/api` and deploy it as a function, reusing the shared execution role.

Open `lambda.tf`.

**Requirements:**

| # | What | Resource |
|---|---|---|
| 1 | Zip `../lambda-src/api` into `build/api.zip` | `data "archive_file"` |
| 2 | Look up the shared execution role by name | `data "aws_iam_role"` |
| 3 | Log group, 14 days retention | `aws_cloudwatch_log_group` |
| 4 | The function: `python3.13`, handler `handler.lambda_handler`, timeout 15, memory 256, env var `BUCKET_NAME` | `aws_lambda_function` |

> **Note:** requirements 1 and 2 are `data` blocks, not `resource` blocks. A `data` block reads something that exists and never changes it. Getting that distinction wrong is how people accidentally destroy other teams' infrastructure.

**Where to start:**

1. Read `handler.py` and find which environment variable it expects.
2. Write requirements 1-3, then `terraform plan`. The archive is built at plan time - you will see the zip appear under `build/`.
3. Add the function last, since it references all three.

<details>
<summary>Hint - the zip</summary>

`archive_file` needs three things: the `type` of archive, the directory to pack (`source_dir`), and where to write it (`output_path`).

Paths are relative to the module, so use `${path.module}/../lambda-src/api`. Hardcoding `/Users/you/...` works on your laptop and nowhere else.

</details>

<details>
<summary>Hint - the role lookup</summary>

`data "aws_iam_role"` takes a single argument: the role's `name`. `main.tf` already has that name in a local value - find it.

What you need from the result is the role's ARN. Data source attributes are read as `data.<type>.<name>.<attribute>`.

</details>

<details>
<summary>Hint - the log group</summary>

The name must be **exactly** `/aws/lambda/<function_name>`. Lambda writes to that name whether or not the group exists, so anything else leaves you with an empty group of your own and a second, auto-created one holding the real logs.

Declaring it yourself is what gives you control over retention, and what lets `terraform destroy` clean it up - remember that yesterday deleting the function left its logs behind.

</details>

<details>
<summary>Hint - the function</summary>

Beyond the obvious `function_name`, `role`, `runtime`, `handler`, `timeout` and `memory_size`, three things are easy to miss:

- `filename` points at the zip the archive data source produced.
- `source_code_hash` must be set to the archive's `output_base64sha256`. Without it Terraform only compares the file *name*, decides nothing changed, and silently ignores your code edits.
- The environment variable goes inside a nested `environment { variables = { … } }` block. Its value should reference the bucket resource, not repeat the name as a string.

Add `depends_on = [aws_cloudwatch_log_group.api]` so the group exists before the first invocation can auto-create it.

</details>

**Terraform documentation:**

https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function

> Solution if you need it: [solutions/lambda.tf](solutions/lambda.tf)

### Deploy it

```bash
terraform fmt
terraform plan
terraform apply
```

Uncomment the `log_group_name` output and apply again.

**Verify:**

```bash
aws lambda invoke \
  --function-name nl-dev-feedback-api-tf-VORNAME \
  --cli-binary-format raw-in-base64-out \
  --payload '{"version":"2.0","routeKey":"POST /feedback","body":"{\"team\":\"platform\",\"rating\":5,\"comment\":\"Invoked from the CLI\"}"}' \
  response.json

cat response.json
```

You should see `"statusCode": 201` and a generated `id`. There is no API in front of the function yet - this call goes straight to Lambda, exactly like the Test tab did yesterday.

---

## Part 3 - The front door

**Goal:** three routes, one integration, and the permission the console gave you for free yesterday.

Open `apigateway.tf`.

**Requirements:**

| # | What | Resource |
|---|---|---|
| 1 | The API, `protocol_type = "HTTP"` | `aws_apigatewayv2_api` |
| 2 | Lambda integration, `integration_type = "AWS_PROXY"` | `aws_apigatewayv2_integration` |
| 3 | `POST /feedback` | `aws_apigatewayv2_route` |
| 4 | `GET /feedback` | `aws_apigatewayv2_route` |
| 5 | `GET /feedback/{id}` | `aws_apigatewayv2_route` |
| 6 | The `$default` stage - **given**, uncomment it with requirement 1 | `aws_apigatewayv2_stage` |
| 7 | Permission for API Gateway to invoke the function | `aws_lambda_permission` |

Requirement 7 is the interesting one. Yesterday the console created it silently when you attached the integration - you saw it under **Lambda → Configuration → Permissions → Resource-based policy statements**. Here nothing is silent. Leave it out and every call returns a 500 while your function is never even reached.

<details>
<summary>Hint - the API and the integration</summary>

The API itself needs a `name` and a `protocol_type`.

The integration needs to know which API it belongs to (`api_id`), what kind it is (`integration_type`), and what to call (`integration_uri`). For Lambda, the URI is not the function ARN - the function resource exposes a separate attribute meant exactly for this. Look for one with `invoke` in its name.

Also set `payload_format_version = "2.0"`, which is the event shape `handler.py` parses.

</details>

<details>
<summary>Hint - the routes</summary>

A route has three arguments: `api_id`, `route_key` and `target`.

The `route_key` is the method and path as one string, exactly as you typed them into the console: `"POST /feedback"`.

The `target` is the string `"integrations/"` followed by the integration's id. Build it with interpolation - you do not need to know the id in advance, Terraform resolves it and works out the dependency order from the reference.

</details>

<details>
<summary>Hint - the permission</summary>

`aws_lambda_permission` needs:

- `statement_id` - any label, e.g. `"AllowExecutionFromAPIGateway"`
- `action` - `"lambda:InvokeFunction"`
- `function_name` - which function may be invoked
- `principal` - which service may do it: `"apigateway.amazonaws.com"`
- `source_arn` - which API specifically

For `source_arn`, the API resource has an `execution_arn` attribute. Append `/*/*` to it so the permission covers every stage and every route, rather than one.

</details>

**Terraform documentation:**

https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage
https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission

> Solution if you need it: [solutions/apigateway.tf](solutions/apigateway.tf)

---

## Part 4 - Deploy and test end to end

Uncomment the `api_url` output in `outputs.tf`, then:

```bash
terraform fmt
terraform validate
terraform plan
terraform apply            # no -target this time - the whole thing
```

Take the URL straight out of the state instead of copying it from anywhere:

```bash
export API=$(terraform output -raw api_url)
echo "$API"
```

Then the same four calls as yesterday:

```bash
# Create
curl -s -X POST "$API/feedback" \
  -H 'content-type: application/json' \
  -d '{"team":"platform","rating":5,"comment":"Built by Terraform this time"}'

# List
curl -s "$API/feedback"

# Read one - paste an id from a response above
curl -s "$API/feedback/PASTE-AN-ID-HERE"

# Invalid on purpose
curl -s -X POST "$API/feedback" \
  -H 'content-type: application/json' \
  -d '{"team":"platform","rating":9}'
```

Logs, live:

```bash
aws logs tail "$(terraform output -raw log_group_name)" --follow
```

**Verify:** you get a `201` with an id, a list with a `count`, a single item, and a `400` on the invalid one - byte for byte the same behaviour as your hand-built stack from yesterday.

Now open the console and put the two next to each other: `…-manual-VORNAME` and `…-tf-VORNAME`. Same services, same settings. One of them you can rebuild from scratch in ninety seconds.

---

## Part 5 - Change something

This is the part that does not exist on Day 1.

### 5.1 - Make a change

Add a lifecycle rule to `s3.tf` that expires feedback after 30 days:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "feedback" {
  bucket = aws_s3_bucket.feedback.id

  rule {
    id     = "expire-old-feedback"
    status = "Enabled"

    filter {
      prefix = "feedback/"
    }

    expiration {
      days = 30
    }
  }
}
```

```bash
terraform plan
```

Read it: one resource to add, nothing else touched. Terraform did not have to re-create the bucket to change its configuration, and it tells you so before doing anything.

```bash
terraform apply
```

### 5.2 - Run it again

```bash
terraform apply
```

`No changes. Your infrastructure matches the configuration.`

Running it twice does nothing the second time. That is what makes it safe to run in a pipeline, on a schedule, or by a colleague who is not sure whether someone already applied it.

### 5.3 - Break it by hand

Go into the console, open your **tf** bucket, and switch versioning **off**. Then:

```bash
terraform plan
```

Terraform notices. It compares what it recorded in state against what is actually in AWS, sees the difference, and offers to put it back. That gap is called **drift**, and finding it is the reason `plan` is worth running even when you have not changed anything.

```bash
terraform apply
```

Versioning is back on.

**Discussion:**

- What would have told you about that change if the bucket had been built on Day 1, by hand?
- Who should be allowed to click in the console at all, once infrastructure lives in code?
- The state file knows which real bucket belongs to `aws_s3_bucket.feedback`. What happens if you lose it? (Try `terraform state list` to see what is in there.)

---

## Cleanup

Do this at the end of the day. It is two steps, because you built two stacks.

### Terraform resources

```bash
# The bucket must be empty, otherwise destroy fails on it
aws s3 rm "s3://$(terraform output -raw bucket_name)" --recursive

terraform destroy
```

Read the destroy plan before confirming, the same way you read the apply plans.

> If `destroy` still fails on the bucket, it is the versioning from Part 1: `aws s3 rm --recursive` removes current objects but leaves old versions and delete markers behind. Easiest fix is the console's **Empty** action on the bucket, then `terraform destroy` again.

**Verify:**

```bash
terraform state list
```

Must come back empty.

### Day 1 resources

Terraform never knew about those, so it cannot remove them. Go back to [../day1/README.md](../day1/README.md#cleanup) and delete them by hand - which is itself a decent closing argument for today.

---

## Best Practices

A workshop configuration is not a production configuration. The main shortcuts we took:

| Workshop | Production |
|---|---|
| Local state in `terraform.tfstate` | Remote backend with locking, e.g. S3 with `use_lockfile` |
| `.terraform.lock.hcl` gitignored | Committed, so everyone resolves the same provider versions |
| One shared IAM role, wildcarded to `nl-dev-feedback-*` | One role per function, scoped to one bucket |
| Everything in one flat directory | Modules, and a directory per environment |
| No authentication on the API | JWT authoriser, or the API not being public at all |
| `terraform apply` from a laptop | A pipeline, with plan on the pull request and apply on merge |
| No tests, no policy checks | `validate`, `fmt -check`, `tflint`, and a policy engine in CI |

The reasoning behind each of these is in [docs/best-practices.md](docs/best-practices.md).

---

## Cheatsheet

Terraform and AWS CLI commands, collected: [docs/cheatsheet.md](docs/cheatsheet.md).

Common stumbling blocks:

- **`BucketAlreadyExists`** - bucket names are globally unique. Someone outside our account has yours. Add a digit to `name_suffix` in `terraform.tfvars`.
- **Nothing happens after you edit `handler.py`** - `source_code_hash` is missing from the function. See the hint in Part 2.
- **Every API call returns 500** - the `aws_lambda_permission` from Part 3 is missing, or its `source_arn` does not match.
- **`ExpiredToken`** - `aws sso login --profile nl-ws`, then carry on where you were.

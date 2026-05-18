# Terraform Workshop

Welcome to this terraform workshop!

By the end you will have:
- Deployed a public static website to AWS using Terraform
- Extracted that setup into a reusable module
- Deployed two more websites using that module with only a few lines of new code

---

## Background: What is Terraform?

Terraform is an **Infrastructure as Code (IaC)** tool. Instead of clicking through the AWS Management Console to create a server, a storage bucket, or a network rule, you describe what you want in plain text files (`.tf` files). Terraform then figures out what needs to be created, changed, or deleted to make the real infrastructure match your description.

Here are the core concepts you'll encounter throughout this workshop:

| Term | What it means |
|------|---------------|
| **Resource** | A single piece of infrastructure — an S3 bucket, a database table, a DNS entry. You declare resources in `.tf` files. |
| **Provider** | A plugin Terraform uses to talk to a specific platform. For example, the `aws` provider knows how to create and manage AWS resources. |
| **State** | Terraform keeps a record of everything it has created in a *state file*. It uses this to know what already exists and what still needs to change. |
| **Plan** | A dry run: `terraform plan` shows exactly what Terraform *would* do, without changing anything real. **Always run this before applying.** |
| **Apply** | `terraform apply` executes the changes shown in the plan. Terraform always asks for confirmation before making real changes. |
| **Variable** | A named input that makes your configuration reusable and flexible — like a parameter in a function. |
| **Module** | A reusable group of resources, packaged in its own folder. Like a function you can call multiple times with different arguments. You'll work with modules in Task 2. |

---

## What we will build

**Task 1 — Static website:** You will provision an S3 bucket, upload an HTML file, configure public access, and enable S3 static website hosting — step by step.

**Task 2 — Modules:** You will extract the Task 1 setup into a reusable Terraform module, then deploy two more websites by calling that module twice.

---

## Repository structure

```
terraform-workshop/
├── resources/
│   ├── static-page/index.html       ← Website file for Task 1
│   ├── static-page-2/index.html     ← Website file for Task 2 (second site)
│   └── static-page-3/index.html     ← Website file for Task 2 (third site)
└── terraform/
    ├── initialize-lock-db/          ← One-time setup: creates your personal state lock table
    │   ├── main.tf
    │   ├── variables.tf
    │   └── default.auto.tfvars      ← You will edit this in Setup Step 4
    ├── main.tf                      ← You will edit this in Setup Step 5
    └── variables.tf
```

During Task 1 you will add new `.tf` files inside `terraform/`. During Task 2 you will create the `terraform/modules/` folder.

---

## Setup

Work through all five steps in order before starting the tasks. If anything fails, ask for help before moving on.

---

### Step 1 – Install the required tools

You need two tools installed on your machine: **Terraform** (to manage infrastructure) and the **AWS CLI** (to authenticate with AWS).

#### macOS

Open a terminal and run:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
```

> If you do not have Homebrew installed yet, follow the instructions at https://brew.sh first.

#### Windows

Open **PowerShell as Administrator** and run:

```powershell
winget install HashiCorp.Terraform
winget install Amazon.AWSCLI
```

> Close and reopen PowerShell after the install so the new commands are available on your PATH.

**Verify both tools are installed correctly:**

```bash
terraform version
aws --version
```

Both commands should print a version number. If either command is not found, check the installation steps again.

---

### Step 2 – Set the `tf` alias

Throughout this workshop we type `tf` instead of `terraform` to save time. This sets up a shell alias that makes `tf` equivalent to `terraform`.

#### macOS / Linux (zsh)

```bash
echo 'alias tf=terraform' >> ~/.zshrc && source ~/.zshrc
```

#### Windows (PowerShell)

```powershell
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -Force }
Add-Content $PROFILE 'Set-Alias tf terraform'
. $PROFILE
```

**Verify the alias works:**

```bash
tf version
```

---

### Step 3 – Log in to AWS via SSO

This workshop runs on a shared AWS account. You authenticate using **AWS Single Sign-On (SSO)** — a central login portal that grants you temporary credentials.

**Configure your SSO profile (first time only):**

```bash
aws configure sso --profile workshop
```

When prompted for the **SSO start URL**, enter:

```
https://nl.awsapps.com/start
```

Accept the defaults for any other prompts (or follow the instructions from the workshop host). A browser tab will open for you to approve the login. Once you see the confirmation, return to your terminal.

**Tell the AWS CLI which profile to use:**

macOS / Linux:
```bash
export AWS_PROFILE=workshop
```

Windows (PowerShell):
```powershell
$env:AWS_PROFILE = "workshop"
```

> This variable is only set for the current terminal session. You will need to set it again every time you open a new terminal window. If you encounter authentication errors later, this is the first thing to check.

**If your session expires at any point:**

```bash
aws sso login --profile workshop
```

**Verify your access:**

```bash
aws s3 ls
```

You should see a list of S3 buckets. An authentication error means your session has expired — run the login command above to refresh it.

---

### Step 4 – Create your personal state lock table

#### Why does Terraform need remote state and a lock?

By default Terraform saves its state file (`terraform.tfstate`) on your local machine. This works fine for solo use, but in a shared environment multiple people could run `tf apply` at the same time and overwrite each other's state.

To prevent this, we store the state file in a central **S3 bucket** (already created for this workshop). On top of that, we use a **DynamoDB table as a lock**: when someone is running `tf apply`, they acquire the lock, and anyone else who tries to apply at the same time is made to wait.

Because you share the S3 bucket with other workshop participants, each person creates their **own DynamoDB lock table** so your locks don't interfere with each other.

**Steps:**

1. Open `terraform/initialize-lock-db/default.auto.tfvars` in your text editor.
2. Replace `-NAME` with your first name or initials. Use **lowercase letters and hyphens only** — no spaces or special characters.
   ```
   dynamodb_table_name = "terraform-state-lock-NAME"
   ```
3. Navigate to the `initialize-lock-db` directory in your terminal:
   ```bash
   cd terraform/initialize-lock-db
   ```
4. Run the commands below. The first downloads the required provider plugins; the second creates your DynamoDB table.
   ```bash
   tf init
   tf plan
   tf apply
   ```
5. Terraform will print a summary of what it plans to create and then ask: `Do you want to perform these actions?` — type `yes` and press Enter.

You should see: `Apply complete! Resources: 1 added, 0 changed, 0 destroyed.`

---

### Step 5 – Configure your personal backend

Now you need to tell the main Terraform project *where* to store your state file. Everyone stores their state in the same shared S3 bucket, but each person uses a unique `key` — think of it as the file path inside the bucket — so your state doesn't overwrite anyone else's.

1. Open `terraform/main.tf` in your editor.
2. Find the `backend "s3"` block near the top of the file, inside the `terraform {}` block:
   ```hcl
   backend "s3" {
     bucket = "terraform-state-nl-devk"
     key    = "infrastructure-NAME"   # ← change this line
   }
   ```
3. Replace `NAME` in the `key` value with your name — use the same value you used in Step 4.
   ```hcl
   key = "infrastructure-NAME"
   ```
4. While you have this file open, also add your DynamoDB table name so that state locking is active:
   ```hcl
   dynamodb_table = "terraform-state-lock-NAME"   # same name as Step 4
   ```
5. Navigate to the `terraform/` directory:
   ```bash
   cd ..
   ```
6. Initialize the backend:
   ```bash
   tf init
   ```

Terraform will connect to the S3 bucket and confirm the backend is ready. You are now fully set up and ready to start the tasks.

---

## Task 1 – Host a Static Website on S3

In this task you will create an S3 bucket and configure it to serve a public static website. All Terraform files you create go inside the `terraform/` directory.

### Understanding resource declarations

Every resource in Terraform follows the same pattern:

```hcl
resource "TYPE" "LOCAL_NAME" {
  argument = "value"
}
```

- `TYPE` is the resource type defined by the provider, for example `aws_s3_bucket`.
- `LOCAL_NAME` is a name you choose — it's only used inside your Terraform code to reference this specific resource from elsewhere.
- The arguments inside the block configure the resource. What arguments exist and which are required is documented in the [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs).

**Referencing another resource** lets you use its attributes without copying values manually. For example:

```hcl
bucket_id = aws_s3_bucket.my_bucket.id
```

This reads the `id` attribute of the resource of type `aws_s3_bucket` that you named `my_bucket`. Terraform automatically figures out the correct order to create the two resources.

**Your workflow for every step:**

```
Write or change .tf files  →  tf plan  →  review the output  →  tf apply
```

Never skip `tf plan`. It shows exactly what will happen before anything is changed in AWS.

### About providers in this workshop

The `terraform/main.tf` file already configures two AWS providers for you:

- `aws.frankfurt` — used for most resources (region: `eu-central-1`)

To assign a specific provider to a resource, add this argument inside its block:

```hcl
provider = aws.frankfurt
```

Use `aws.frankfurt` for every resource you create in Task 1.

---

### 1.1 – Create an S3 bucket

**Goal:** Create a new file called `terraform/s3.tf` and declare an `aws_s3_bucket` resource inside it. The bucket name must be **globally unique across all of AWS** — prefix it with your name, for example `justus-workshop-static-page`.

Run `tf plan` and read the output to understand what Terraform is going to do, then run `tf apply`.

**Verify:** After applying, open the AWS Console and navigate to S3 — your bucket should appear in the list. Alternatively, run `aws s3 ls` in your terminal.

**Terraform documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket

<details>
<summary>Hint</summary>

The `aws_s3_bucket` resource only needs a `bucket` argument (the name) and the `provider` argument at this stage. Keep it minimal — you will configure the bucket's behaviour through separate, dedicated resources in the following steps. That's the Terraform approach: one resource, one concern.

S3 bucket names must be globally unique across all AWS accounts worldwide. Including your name, company, and today's date (e.g. `justus-nl-20250517`) is a reliable way to avoid conflicts with other people's buckets.

</details>

---

### 1.2 – Upload the website file

**Goal:** Add an `aws_s3_object` resource to `terraform/s3.tf` that uploads `../resources/static-page/index.html` into your bucket. Use a **reference** to your bucket resource rather than copying the bucket name as a string. Set the correct content type so browsers know to render the file as a webpage.

Run `tf plan` → `tf apply`, then verify the file appears inside your bucket under the **Objects** tab in the AWS Console.

**Terraform documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object

<details>
<summary>Hint</summary>

`aws_s3_object` needs three key arguments:

- `bucket` — the name of the bucket to upload into. Use a resource reference instead of a hard-coded string: `aws_s3_bucket.YOUR_LOCAL_NAME.id`
- `key` — the name the file will have inside S3, e.g. `"index.html"`
- `source` — the local file path, relative to the `terraform/` directory

The correct `content_type` for an HTML file is `"text/html"`. Without this, browsers will download the file instead of rendering it.

To ensure Terraform notices when the file contents change and re-uploads it, set `etag = filemd5("../resources/static-page/index.html")`. Terraform compares this hash on every plan and triggers an update if the file changes.

</details>

---

### 1.3 – Allow public read access

By default, AWS blocks all public access to every S3 bucket. To host a public website, you need to take two separate steps:

1. **Disable the "Block Public Access" settings** on the bucket.
2. **Attach a bucket policy** that explicitly grants any anonymous internet visitor the right to read objects.

Both require their own Terraform resource. After applying both, any internet user should be able to fetch `index.html` without authenticating to AWS.

**Goal:** Add both of these resources to `s3.tf` and apply them.

**Terraform documentation:**
- Public access block: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
- Bucket policy: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy

<details>
<summary>Hint — disabling Block Public Access</summary>

`aws_s3_bucket_public_access_block` has four boolean arguments — `block_public_acls`, `block_public_policy`, `ignore_public_acls`, and `restrict_public_buckets` — all of which default to `true` (everything blocked). Set all four to `false` to lift the restriction entirely.

Reference the same bucket you created in step 1.1.

</details>

<details>
<summary>Hint — bucket policy</summary>

A bucket policy is a JSON document defining who can do what with your bucket. The `aws_s3_bucket_policy` resource takes a `policy` argument containing that JSON as a string.

The policy you need grants the following:
- **Principal:** `"*"` — anyone, including unauthenticated users
- **Action:** `"s3:GetObject"` — the right to download objects
- **Resource:** every object in your bucket — the ARN pattern is `"arn:aws:s3:::YOUR_BUCKET_NAME/*"`

Using Terraform's built-in `jsonencode()` function lets you write the JSON as a native HCL map, which avoids quoting issues and is easier to read.

**Important ordering constraint:** AWS will reject the bucket policy as long as "Block Public Access" is still enabled. Terraform is not aware of this AWS-specific dependency automatically — you must tell it explicitly by adding `depends_on = [aws_s3_bucket_public_access_block.YOUR_LOCAL_NAME]` to the bucket policy resource. This guarantees the block public access settings are applied before the policy.

</details>

**Verify:** Open a private / incognito browser window. In the AWS Console, navigate to your bucket, click on `index.html`, and copy the **Object URL** (visible under the Properties or Details pane). Paste that URL into the private browser window. You should be able to access the file without being logged in to AWS. If you see an "Access Denied" error, re-check both resources from this step.

---

### 1.4 – Enable static website hosting

When a browser requests an object from a regular S3 URL, S3 returns the file as a plain download. S3's static website hosting feature changes this behaviour: it serves the content with the correct HTTP response headers so browsers render it as a proper webpage, and it serves `index.html` automatically when a visitor loads the root URL.

**Goal:** Add an `aws_s3_bucket_website_configuration` resource to `s3.tf` that enables static website hosting and sets `index.html` as the index document. After applying, S3 exposes a dedicated **website endpoint URL** — use that URL to open your website in a browser.

**Terraform documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration

<details>
<summary>Hint</summary>

`aws_s3_bucket_website_configuration` requires an `index_document` block with a `suffix` argument set to `"index.html"`.

After applying, the website endpoint is available as an attribute of this resource: `aws_s3_bucket_website_configuration.YOUR_LOCAL_NAME.website_endpoint`. You can make Terraform print it automatically at the end of every `tf apply` by adding an `output` block:

```hcl
output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.YOUR_LOCAL_NAME.website_endpoint}"
}
```

Run `tf apply` again (Terraform will notice the new output block) or run `tf output` to print all outputs without making any changes.

</details>

**Verify:** Open the website endpoint URL in your browser. You should see an animated "It's Alive!" page. If you see an XML "AccessDenied" error instead, go back to step 1.3 and double-check the bucket policy and the public access block settings.

---

### Bonus – Serve the website via CloudFront (HTTPS)

S3 website endpoints only support plain HTTP. **CloudFront** is AWS's global content delivery network (CDN). Placing it in front of your S3 bucket adds HTTPS support and a CloudFront-provided domain name — no custom domain required.

This is a larger task. It involves:

- An `aws_cloudfront_origin_access_control` resource to allow CloudFront to fetch objects from your bucket using a secure internal channel
- An `aws_cloudfront_distribution` resource configured with your S3 bucket as the origin
- Updating your bucket policy so that only CloudFront can access the bucket, instead of the public internet directly

**Terraform documentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution

---

## Task 2 – Reuse with a Terraform Module

You now have a working static website made up of several Terraform resources. To deploy a second and a third website, you could copy all those resources — but maintaining three nearly identical copies of the same code is fragile and tedious. Instead, you will extract the setup into a **reusable module**.

### What is a module?

A module is simply a directory that contains `.tf` files. When your root configuration calls a module, Terraform reads those files as if you had written them directly in the root — but uses the variable values you pass in. You define the module once and call it as many times as you need, each time with different inputs. Think of it exactly like calling a function in a programming language.

Your module will live at `terraform/modules/static-webpage/`.

---

### 2.1 – Create the module folder structure

**Goal:** Create the following two empty files:

```
terraform/modules/static-webpage/main.tf
terraform/modules/static-webpage/variables.tf
```

No Terraform commands are needed yet — these are just empty files to establish the structure.

---

### 2.2 – Move your resources into the module

**Goal:** Cut all `aws_s3_*` resources from `terraform/s3.tf` and paste them into `terraform/modules/static-webpage/main.tf`. The `terraform {}` block, `provider` blocks, and `output` blocks stay in the root `main.tf` — do not copy those into the module.

Once the resources are moved you can delete `terraform/s3.tf`.

> **Providers inside modules — important:** The root `main.tf` uses *aliased* providers (`aws.frankfurt`). A child module must explicitly declare which provider aliases it expects. Add the following block at the top of `terraform/modules/static-webpage/main.tf`:
>
> ```hcl
> terraform {
>   required_providers {
>     aws = {
>       source                = "hashicorp/aws"
>       configuration_aliases = [aws.frankfurt]
>     }
>   }
> }
> ```
>
> This tells Terraform: "this module requires a provider configured under the alias `aws.frankfurt`." You will pass the actual provider in when you call the module in step 2.4.

---

### 2.3 – Declare input variables for the module

Right now the resources in the module contain hard-coded values: your bucket name and the file path. Replace those with **variables** so the module can be called with different inputs each time.

**Goal:** Add two input variables to `terraform/modules/static-webpage/variables.tf`:

| Variable | Type | Description |
|----------|------|-------------|
| `name` | `string` | A short identifier for this website. Used to construct a unique bucket name. |
| `filepath` | `string` | The local path to the HTML file to upload, relative to the `terraform/` directory. |

Then update the resources in `main.tf` inside the module to use `var.name` and `var.filepath` instead of the hard-coded values.

**Terraform documentation:** https://developer.hashicorp.com/terraform/language/values/variables

<details>
<summary>Hint</summary>

A variable is declared with a `variable` block:

```hcl
variable "name" {
  description = "A short identifier for this website deployment."
  type        = string
}
```

Inside the module's resource definitions, reference the variable using `var.name` and `var.filepath`.

For the bucket name, concatenate the variable with a fixed prefix to keep names unique across multiple module calls. For example: `bucket = "workshop-${var.name}"`. The `${}` syntax is Terraform string interpolation — it embeds the value of an expression inside a string.

</details>

---

### 2.4 – Call the module from the root configuration

**Goal:** Add a `module` block to `terraform/main.tf` that calls your new module and passes values for `name`, `filepath`, and the provider. Use the same values you previously had hard-coded (your first website, `static-page`).

After adding the module block, run `tf init` first (required whenever you add a new `module` block), then `tf plan` and `tf apply`.

**Terraform documentation:** https://developer.hashicorp.com/terraform/language/modules/syntax

<details>
<summary>Hint</summary>

A module call in `main.tf` looks like this:

```hcl
module "static_page_1" {
  source = "./modules/static-webpage"

  providers = {
    aws.frankfurt = aws.frankfurt
  }

  name     = "justus-static-page-1"
  filepath = "../resources/static-page/index.html"
}
```

- `source` is the path to the module directory, relative to `main.tf`.
- `providers` passes the Frankfurt provider alias into the module. The key (`aws.frankfurt`) matches the `configuration_aliases` declaration you added in step 2.2; the value (`aws.frankfurt`) refers to the provider configured in the root `main.tf`.
- `name` and `filepath` map to the variables you declared in step 2.3.

**Remember:** `tf init` must be re-run after every new `module` block that introduces a new `source` path. Terraform uses init to register the module.

</details>

If you added an `output` block in step 1.4, move it into `terraform/modules/static-webpage/main.tf`. To expose that output from the root level, add an output block in root `main.tf` that references the module:

```hcl
output "website_url_1" {
  value = module.static_page_1.website_url
}
```

For this to work, the module itself must also declare an `output` block that exposes `website_url`. See: https://developer.hashicorp.com/terraform/language/values/outputs

---

### 2.5 – Deploy two more websites using the module

**Goal:** Add two more `module` blocks to `terraform/main.tf` — one for each of the remaining HTML files:

- `../resources/static-page-2/index.html`
- `../resources/static-page-3/index.html`

Give each module block a unique name (the first argument after `module`) and a unique `name` variable value so the S3 bucket names don't collide.

Run `tf plan` and confirm Terraform plans to create resources for both new websites. Then run `tf apply`.

**Verify:** Open the website endpoint URL for each of the three buckets. You should see three distinct pages.

---

## Cleanup

When you are done with the workshop, remove all resources you created to avoid ongoing AWS charges:

```bash
tf destroy
```

Terraform will list everything it is about to delete and ask for confirmation. Type `yes` to proceed. Wait for the destroy to complete before closing your terminal.

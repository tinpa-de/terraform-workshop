# Internal AWS Workshop - Day 1

Today you build the backend of a feedback portal by hand, in the AWS Management Console. Three services, no code generation, no automation - you click, you read what AWS asks you, and you learn where things live.

By the end of today you will have:
- Created an S3 bucket with versioning and encryption in the console
- Deployed a Python Lambda function and wired it to an existing IAM role
- Put an HTTP API in front of that function with three routes
- Called your own API from the terminal and watched the logs
- Queried all of it again from the AWS CLI

Tomorrow you build exactly the same thing in Terraform. Pay attention to how many clicks today costs you.

---

## Use Case: Feedback Portal

Someone submits feedback over HTTP, it lands in S3 as a JSON file, and can be read back.

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

| Method | Path | Does |
|---|---|---|
| `POST` | `/feedback` | Store new feedback (`team`, `rating` 1-5, `comment`) and return its id |
| `GET` | `/feedback` | List all feedback, newest first |
| `GET` | `/feedback/{id}` | Read one piece of feedback |

---

## AWS Services Today

| Service | What does it do? | Where in the console |
|---|---|---|
| **S3** | Object storage. You put files in, you get files out. No servers, no size limit. | Services → Storage → S3 |
| **Lambda** | Runs your code on demand. You upload a function, AWS runs it when something calls it. | Services → Compute → Lambda |
| **API Gateway** | Turns HTTP requests into invocations of something else - here, your Lambda. | Services → Networking → API Gateway |
| **CloudWatch Logs** | Everything your function prints ends up here. | Services → Management → CloudWatch |
| **IAM** | Who is allowed to do what. Today you only *use* a role, you do not create one. | Services → Security → IAM |

---

## Setup

Work through all four steps in order. If something does not work, ask before moving on.

---

### Step 1 - Sign in to AWS

Open the SSO portal:

https://nl.awsapps.com/start/#/

Pick the account **`654654436000`**, then the permission set **`WriteAccess`**, then **Management console**.

> **Important:** set the region to **Europe (Ireland) eu-west-1** in the dropdown at the top right, and check it again every time a page looks emptier than you expect. Resources created in the wrong region are invisible from the right one - this is the single most common source of confusion today.

**Verify:** the region selector at the top right reads `Ireland`, and the account menu at the top right shows `654654436000`.

---

### Step 2 - Install the AWS CLI

The console is not the only way in. You will use the CLI in Part 5 to look at what you built.

macOS / Linux:
```bash
brew install awscli
```

Windows (PowerShell):
```powershell
winget install Amazon.AWSCLI
```

> Close and reopen your terminal after installing, so the new command is on your PATH.

**Verify:**

```bash
aws --version
```

This must print a version number, e.g. `aws-cli/2.31.0`. If the command is not found, the install did not finish.

---

### Step 3 - Give the CLI access to the account

The CLI needs credentials of its own. We use SSO, so you never handle a long-lived access key.

```bash
aws configure sso
```

Answer the prompts:

| Prompt | Answer |
|---|---|
| SSO session name | `nl` |
| SSO start URL | `https://nl.awsapps.com/start/#/` |
| SSO region | `eu-west-1` |
| SSO registration scopes | press Enter to accept the default |
| Account / role | pick `654654436000` and `WriteAccess` |
| Default client Region | `eu-west-1` |
| Default output format | `json` |
| Profile name | `nl-ws` |

A browser window opens for you to approve the login. Then tell your shell to use that profile:

macOS / Linux:
```bash
export AWS_PROFILE=nl-ws
```

Windows (PowerShell):
```powershell
$env:AWS_PROFILE = "nl-ws"
```

> This variable only applies to the current terminal window. Open a new one and you have to set it again - or pass `--profile nl-ws` on every command.

**Verify:**

```bash
aws sts get-caller-identity
```

The output must contain `"Account": "654654436000"`. An error here means the credentials are not set - fix it now, everything after this depends on it.

> Your SSO session expires after a few hours. When commands suddenly fail with an expired-token error, run `aws sso login --profile nl-ws` and carry on.

---

### Step 4 - Claim your resource names

Everyone works in the same AWS account, so every name you create carries your first name. Write yours down now and use it consistently - all instructions below say `VORNAME` where your first name goes, in lowercase.

| Resource | Name |
|---|---|
| S3 bucket | `nl-dev-feedback-manual-VORNAME` |
| Lambda function | `nl-dev-feedback-api-manual-VORNAME` |
| HTTP API | `nl-dev-feedback-manual-VORNAME` |

`manual` marks these as the hand-built ones. Tomorrow's Terraform resources use `tf` instead, so both sets can exist side by side.

> S3 bucket names are globally unique across all of AWS, not just our account. If yours is taken, append a digit: `nl-dev-feedback-manual-anna2`.

---

## Part 1 - The S3 bucket

**Goal:** a private, versioned, encrypted bucket to hold the feedback files.

1. Console → **S3** → **Create bucket**.
2. **Bucket type:** General purpose.
3. **Bucket name:** `nl-dev-feedback-manual-VORNAME`.
4. **Block Public Access settings:** leave all four boxes **checked**. Nothing in this workshop is served publicly from S3 - the API is the only way in.
5. **Bucket Versioning:** select **Enable**.
6. **Default encryption:** leave it on **Server-side encryption with Amazon S3 managed keys (SSE-S3)**.
7. **Create bucket**.

<details>
<summary>Hint - what versioning actually buys you</summary>

With versioning off, writing to the same key twice destroys the first object. With it on, S3 keeps both and the old one becomes a previous version you can restore.

It also changes deletion: deleting an object only adds a delete marker. That is why an "empty-looking" versioned bucket can still refuse to be deleted - you will run into this during cleanup.

</details>

**Verify:**

```bash
aws s3 ls | grep VORNAME
aws s3api get-bucket-versioning --bucket nl-dev-feedback-manual-VORNAME
```

The second command must print `{ "Status": "Enabled" }`. Empty output means versioning is off - go back and enable it.

---

## Part 2 - The Lambda function

**Goal:** deploy the feedback API code and let it write into your bucket.

### 2.1 - Create the function

1. Console → **Lambda** → **Create function**.
2. **Author from scratch**.
3. **Function name:** `nl-dev-feedback-api-manual-VORNAME`.
4. **Runtime:** `Python 3.13`.
5. Open **Change default execution role**, choose **Use an existing role**, and pick **`nl-dev-feedback-api-role`** from the dropdown.
6. **Create function**.

> **Important:** step 5 is easy to miss. The default is *Create a new role with basic Lambda permissions*, which produces a function that may write logs but cannot touch S3. If you took the default, go to **Configuration → Permissions → Edit** and switch the role.

<details>
<summary>Hint - why we are not creating the role ourselves</summary>

A Lambda function does not act as you. It assumes an IAM role, and that role's policy decides what the code may do. Ours grants two things: writing logs, and reading/writing objects in any bucket named `nl-dev-feedback-*`.

The role was created before the workshop so that everyone shares one and nobody has to hand-write a trust policy. You will meet it again tomorrow as a `data "aws_iam_role"` lookup.

</details>

### 2.2 - Paste the code

1. On the **Code** tab, the editor shows a file called `lambda_function.py` with a stub in it.
2. Open [lambda-src/handler.py](lambda-src/handler.py) from this repository, copy **everything**, and replace the entire contents of `lambda_function.py`.
3. Click **Deploy** (or Ctrl-S). The tab title stops showing "Changes not deployed".

> Leave the **Handler** setting at `lambda_function.lambda_handler`. The file in the console is called `lambda_function.py` and our code defines a function called `lambda_handler`, so the default already points at the right place. Tomorrow the file is called `handler.py`, and the handler will read `handler.lambda_handler` - same two halves, `<file>.<function>`.

### 2.3 - Configure it

1. **Configuration → Environment variables → Edit → Add environment variable**
   - Key: `BUCKET_NAME`
   - Value: `nl-dev-feedback-manual-VORNAME`
   - **Save**
2. **Configuration → General configuration → Edit**
   - **Timeout:** `15` sec
   - **Memory:** `256` MB
   - **Save**

> The code reads the bucket name from the environment instead of hardcoding it. That is the only reason the exact same file can run against today's bucket and tomorrow's.

### 2.4 - Test it

1. Go to the **Test** tab, choose **Create new event**, name it `post-feedback`.
2. Replace the event JSON with:

```json
{
  "version": "2.0",
  "routeKey": "POST /feedback",
  "rawPath": "/feedback",
  "headers": { "content-type": "application/json" },
  "requestContext": { "http": { "method": "POST", "path": "/feedback" } },
  "body": "{\"team\":\"platform\",\"rating\":4,\"comment\":\"Console test event\"}",
  "isBase64Encoded": false
}
```

3. **Save**, then **Test**.

You should get a green box with `"statusCode": 201` and a body containing a generated `id`.

<details>
<summary>Hint - it failed, now what</summary>

Read the error text in the result panel, not just the red banner.

- `KeyError: 'BUCKET_NAME'` - the environment variable is missing or misspelled. Step 2.3.
- `AccessDenied` on `PutObject` - the function is using the wrong execution role. Step 2.1, point 5.
- `NoSuchBucket` - the bucket name in the environment variable does not match the bucket you created.
- `Unable to import module 'lambda_function'` - the paste went wrong, or you renamed the file. Check the Code tab.

</details>

**Verify:**

```bash
aws s3 ls s3://nl-dev-feedback-manual-VORNAME/feedback/
```

One `.json` object should be listed. That file is the feedback your test event just created.

---

## Part 3 - The HTTP API

**Goal:** make the function reachable over the internet under three routes.

1. Console → **API Gateway** → **Create API** → next to **HTTP API**, click **Build**.
2. **Add integration** → **Lambda** → region `eu-west-1` → your function `nl-dev-feedback-api-manual-VORNAME`.
3. **API name:** `nl-dev-feedback-manual-VORNAME`. → **Next**
4. **Configure routes.** API Gateway prefills one route. Edit it and add the other two, so you end up with exactly these three, all pointing at your Lambda integration:

   | Method | Resource path |
   |---|---|
   | `POST` | `/feedback` |
   | `GET` | `/feedback` |
   | `GET` | `/feedback/{id}` |

   → **Next**
5. **Configure stages.** Leave the `$default` stage with **Auto-deploy** enabled. → **Next**
6. **Create**.
7. On the API's detail page, copy the **Invoke URL**. It looks like `https://abc123xyz.execute-api.eu-west-1.amazonaws.com`.

> The `{id}` in the third route is a path parameter. API Gateway passes whatever is in that position to your function, which uses it as the S3 key. That is how `GET /feedback/9f3c…` finds one specific file.

<details>
<summary>Hint - what the console just did behind your back</summary>

Creating the integration also created a **resource-based policy** on your Lambda that allows this particular API to invoke it. Without it, every call would fail with a 500 and your function would never run.

You can see it under **Lambda → Configuration → Permissions → Resource-based policy statements**. Have a look - tomorrow you have to write that permission yourself, and it is the single most common thing people forget.

</details>

---

## Part 4 - Call your API

Put the invoke URL into a shell variable so the commands below stay readable:

macOS / Linux:
```bash
export API=https://abc123xyz.execute-api.eu-west-1.amazonaws.com
```

Windows (PowerShell):
```powershell
$env:API = "https://abc123xyz.execute-api.eu-west-1.amazonaws.com"
```

Create some feedback:

```bash
curl -s -X POST "$API/feedback" \
  -H 'content-type: application/json' \
  -d '{"team":"platform","rating":5,"comment":"The coffee machine finally works"}'
```

List everything:

```bash
curl -s "$API/feedback"
```

Read a single entry - take an `id` from one of the responses above:

```bash
curl -s "$API/feedback/PASTE-AN-ID-HERE"
```

Try an invalid request and watch the function reject it:

```bash
curl -s -X POST "$API/feedback" \
  -H 'content-type: application/json' \
  -d '{"team":"platform","rating":9}'
```

**Verify:** the first call returns `201` with an `id`, the list call returns a growing `count`, and the last one returns a `400` with an error message.

### Read the logs

Console → **CloudWatch** → **Log groups** → `/aws/lambda/nl-dev-feedback-api-manual-VORNAME` → newest log stream. Every `print()` from the function shows up here, along with duration and memory used per invocation.

The same thing from the terminal, live:

```bash
aws logs tail /aws/lambda/nl-dev-feedback-api-manual-VORNAME --follow
```

Leave that running in a second terminal and fire another `curl` - the log line appears within a second or two. Press Ctrl-C to stop.

---

## Part 5 - The same things from the CLI

Everything you clicked together is also queryable from the command line. This is how you check state without hunting through six console tabs.

```bash
# All buckets you can see, filtered to yours
aws s3 ls | grep VORNAME

# Bucket settings
aws s3api get-bucket-versioning --bucket nl-dev-feedback-manual-VORNAME
aws s3api get-bucket-encryption --bucket nl-dev-feedback-manual-VORNAME

# What is actually stored
aws s3 ls s3://nl-dev-feedback-manual-VORNAME/feedback/ --recursive --human-readable

# Download one object and look at it
aws s3 cp s3://nl-dev-feedback-manual-VORNAME/feedback/PASTE-AN-ID-HERE.json -
```

```bash
# Your Lambda functions, just name and runtime
aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `VORNAME`)].[FunctionName,Runtime,Timeout,MemorySize]' \
  --output table

# Its configuration in full, including the environment variables
aws lambda get-function-configuration \
  --function-name nl-dev-feedback-api-manual-VORNAME
```

```bash
# Your APIs and their invoke endpoints
aws apigatewayv2 get-apis \
  --query 'Items[?contains(Name, `VORNAME`)].[Name,ApiEndpoint,ProtocolType]' \
  --output table
```

**Discussion:** you have now built something that works. A colleague asks you to set up the same thing for their team, in another region.

- How long would that take, clicking?
- How would you tell them exactly what you did - including the settings you left on their defaults?
- How would you find out, in three months, whether someone changed one of these settings?

That is tomorrow.

---

## Cleanup

**Leave everything running.** Tomorrow you build the same stack with Terraform and compare the two side by side - that only works if today's resources still exist.

At the end of Day 2, come back here and delete them in this order. Note that nothing below is Terraform's problem: these resources were made by hand, so they have to be unmade by hand.

1. **API Gateway** → select `nl-dev-feedback-manual-VORNAME` → **Actions → Delete**.
2. **Lambda** → select `nl-dev-feedback-api-manual-VORNAME` → **Actions → Delete**.
3. **CloudWatch → Log groups** → delete `/aws/lambda/nl-dev-feedback-api-manual-VORNAME`. Deleting a function does not delete its logs.
4. **S3** → select your bucket → **Empty**, type the confirmation, then **Delete**.

> A versioned bucket is not empty until its object *versions* and delete markers are gone too. The console's **Empty** action handles that. From the CLI, `aws s3 rm --recursive` does not - it leaves the old versions behind and the delete then fails.

**Verify:**

```bash
aws s3 ls | grep VORNAME
aws lambda list-functions --query 'Functions[?contains(FunctionName, `VORNAME`)].FunctionName'
aws apigatewayv2 get-apis --query 'Items[?contains(Name, `VORNAME`)].Name'
```

All three must come back empty.

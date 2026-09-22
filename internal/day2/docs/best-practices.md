# Best Practices - what we deliberately did not do

Everything in this workshop works. Almost none of it is how you would set this up for a system that other people depend on. This document lists the shortcuts, what each one costs, and what you would do instead.

Read it after Part 5, or during the apply in Part 4 while you are waiting.

---

## 1. State

**Workshop:** a local `terraform.tfstate` file in `terraform/`, gitignored.

That file is the only record of which real AWS resource belongs to which block in your code. Lose it and Terraform no longer knows it owns your bucket - the next `apply` tries to create a second one and fails. Two people applying at the same time corrupt it. And it contains every attribute of every resource in plain text, including anything marked `sensitive`.

**Better:** a remote backend with locking and versioning.

```hcl
terraform {
  backend "s3" {
    bucket       = "nl-terraform-state"
    key          = "feedback/dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

- Versioning on the state bucket gives you a way back from a bad apply.
- `use_lockfile = true` stops two concurrent applies. (Older setups used a DynamoDB table for this; it is no longer needed.)
- Treat the state bucket as sensitive. It is.

---

## 2. Provider versions

**Workshop:** `.terraform.lock.hcl` is gitignored, and constraints are loose (`~> 6.0`).

Everyone therefore resolves slightly different provider versions, and a `plan` on your laptop can differ from a `plan` on someone else's.

**Better:** commit `.terraform.lock.hcl`. It is not a secret and it is not noise - it is the reason a plan is reproducible. Update it deliberately with `terraform init -upgrade` and review the diff like any other dependency bump.

---

## 3. IAM

**Workshop:** one execution role, shared by everyone, allowed to read and write any bucket matching `nl-dev-feedback-*`.

That wildcard means your function can read your colleague's feedback. In a workshop that is a feature - fewer moving parts, nobody blocked on permissions. Anywhere else it is a finding.

**Better:**

- One role per function, created alongside it in Terraform.
- Resource ARNs without wildcards: this function, this bucket, this prefix.
- Separate the actions: if the function only ever writes, do not grant `s3:DeleteObject`.
- Let Terraform own the role. We split it out here only so that participants did not need IAM write access.

---

## 4. The API is wide open

**Workshop:** anyone with the URL can POST feedback. There is no authentication, no authorisation, no rate limit beyond the stage's throttling, and no CORS configuration.

**Better:** pick one and mean it.

- A JWT authoriser in front of the routes, validating tokens from your identity provider.
- IAM authorisation, if the callers are other AWS services.
- Or: do not expose it publicly at all. A private API behind a VPC endpoint is the right answer more often than people expect.

Also worth adding: request validation at the gateway rather than only in the handler, and a WAF if it really is public.

---

## 5. Lambda packaging

**Workshop:** `data "archive_file"` zips the source directory at plan time, on your laptop.

This works because our function has no dependencies beyond boto3, which the runtime provides. The moment you add one, you are `pip install -t`-ing into the source directory, and the zip depends on which Python and which OS you happened to run the plan from.

**Better:**

- Build the artefact in CI, not during a plan, and upload it to S3. Point the function at `s3_bucket` / `s3_key` instead of `filename`.
- Or build a container image and use `package_type = "Image"`.
- Either way, the build is reproducible and the plan stops depending on the machine it runs on.

---

## 6. Observability

**Workshop:** `print()` to CloudWatch Logs, 14 days retention, no alarms.

You will find a problem if you go looking for it. Nothing tells you to go looking.

**Better:**

- Structured logs (JSON), so you can query them with Logs Insights instead of grepping.
- Metric filters and alarms on the things that matter: 5xx rate, Lambda errors, throttles, duration approaching the timeout.
- X-Ray or another tracing tool once more than one service is involved.
- A dashboard someone actually looks at.

---

## 7. Code layout

**Workshop:** one flat directory, one environment, resource names that carry a person's first name.

**Better:** as soon as there is a second environment or a second team:

- Modules for the reusable parts, with their own `variables.tf` and `outputs.tf`, and an input contract you can read without opening `main.tf`.
- A directory (or a workspace, or a separate state key) per environment, so `dev` and `prod` cannot be confused.
- Names derived from variables only - no personal names, no `-test2` left over from an experiment.

The flat layout here is not a mistake, though. Three resources do not need modules, and reaching for them too early is its own problem.

---

## 8. Nothing checks the code

**Workshop:** you run `fmt` and `plan` when you remember to.

**Better:** a pipeline that, on every pull request, runs `terraform fmt -check`, `terraform validate`, `terraform plan`, and posts the plan as a comment. On merge to the main branch, and only there, `terraform apply`.

Add `tflint` for provider-specific mistakes, and a policy tool (OPA, Sentinel, `checkov`) for the rules your organisation cares about - "no public buckets", "every resource is tagged".

At that point nobody needs credentials on their laptop, which removes a whole class of accident.

---

## 9. Secrets

**Workshop:** there are none, which is why this was easy.

Note that `terraform.tfvars` is gitignored for a reason, and that marking a variable `sensitive = true` hides it from CLI output but **not** from the state file.

**Better:** keep secrets out of Terraform entirely. Put them in Secrets Manager or Parameter Store, and pass the *reference* - the ARN or the parameter name - to the application, which resolves it at runtime.

---

## 10. Cost and lifecycle

**Workshop:** nothing here costs meaningful money, and cleanup is manual.

**Better:** budgets and cost alarms per account, lifecycle rules on anything that accumulates objects (you added one in Part 5), and a convention that non-production environments are destroyed rather than left running. The tag we set on everything - `Workshop = "NL-2026"` - is exactly what makes that enforceable.

---

## One thought to take away

Terraform is not "the correct setup". Terraform is "the setup you have today, written down and repeatable".

None of the points above are prerequisites for starting. They are what you add as "it works on dev" turns into "it has to still work at three in the morning".

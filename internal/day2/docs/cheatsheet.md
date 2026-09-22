# Cheatsheet

Everything you need on Day 2, in one place.

---

## Terraform

### Initialisation

```bash
terraform init                    # download providers, once per directory
terraform init -upgrade           # re-resolve provider versions within your constraints
terraform init -reconfigure       # forget the current backend settings and start over
```

### Plan and apply

```bash
terraform plan                          # what would change? changes nothing
terraform plan -out=tfplan              # save the plan so apply runs exactly it
terraform apply                         # apply, after confirming with "yes"
terraform apply tfplan                  # apply a saved plan, no confirmation prompt
terraform apply -target=aws_s3_bucket.feedback   # only this resource (see below)
terraform apply -auto-approve           # no confirmation - careful
```

> `-target` applies a configuration you never fully planned. Fine while building something up step by step in a workshop, a warning sign in a repository.

### Destroy

```bash
terraform destroy                       # delete everything in this configuration
terraform plan -destroy                 # see what destroy would remove, without doing it
```

### State

```bash
terraform state list                    # which resources does Terraform own?
terraform state show aws_s3_bucket.feedback   # every attribute of one resource
terraform show                          # everything, in full
terraform state rm aws_s3_bucket.feedback     # forget a resource without deleting it
terraform import aws_s3_bucket.feedback my-bucket   # adopt an existing resource
```

`state rm` and `import` are how you move hand-built resources - like yesterday's - under Terraform's control, or out of it.

### Outputs and variables

```bash
terraform output                        # all outputs
terraform output api_url                # one output, quoted
terraform output -raw api_url           # one output, unquoted - for $(…) and scripts
terraform output -json                  # all outputs as JSON, for jq

terraform plan -var="name_suffix=anna"  # set a variable on the command line
TF_VAR_name_suffix=anna terraform plan  # or through the environment
```

`-raw` only works for strings and numbers. For a map or an object, use `-json` and pipe it through `jq`.

### Formatting and checks

```bash
terraform fmt                           # reformat the files in this directory
terraform fmt -recursive                # and every subdirectory
terraform fmt -check -diff              # report without changing - what CI runs
terraform validate                      # syntax and internal consistency, no AWS calls
terraform console                       # REPL - try out expressions and locals
```

`terraform console` is underused. Type `local.bucket_name` into it and it prints the resolved value.

### When something is stuck

```bash
terraform refresh                       # re-read reality into state (plan does this too)
terraform apply -replace=aws_lambda_function.api   # force-recreate one resource
TF_LOG=DEBUG terraform plan             # very verbose provider logging
```

---

## AWS CLI

### Credentials

```bash
aws sso login --profile nl-ws           # refresh an expired SSO session
export AWS_PROFILE=nl-ws                # use this profile for everything (macOS/Linux)
aws sts get-caller-identity             # who am I, and in which account?
aws configure list                      # where are my current credentials coming from?
```

### S3

```bash
aws s3 ls                                          # all buckets
aws s3 ls s3://BUCKET/feedback/ --recursive        # objects under a prefix
aws s3 cp s3://BUCKET/feedback/ID.json -           # print one object to the terminal
aws s3 rm s3://BUCKET --recursive                  # empty a bucket (current versions only)

aws s3api get-bucket-versioning --bucket BUCKET
aws s3api get-bucket-encryption  --bucket BUCKET
aws s3api get-public-access-block --bucket BUCKET
aws s3api list-object-versions --bucket BUCKET     # what a versioned bucket really holds
```

### Lambda

```bash
aws lambda list-functions \
  --query 'Functions[?contains(FunctionName, `VORNAME`)].[FunctionName,Runtime]' \
  --output table

aws lambda get-function-configuration --function-name FUNCTION

aws lambda invoke \
  --function-name FUNCTION \
  --cli-binary-format raw-in-base64-out \
  --payload '{"version":"2.0","routeKey":"GET /feedback"}' \
  response.json
```

### API Gateway

```bash
aws apigatewayv2 get-apis \
  --query 'Items[?contains(Name, `VORNAME`)].[Name,ApiId,ApiEndpoint]' \
  --output table

aws apigatewayv2 get-routes --api-id API_ID \
  --query 'Items[].RouteKey' --output table
```

### Logs

```bash
aws logs tail /aws/lambda/FUNCTION --follow          # live
aws logs tail /aws/lambda/FUNCTION --since 15m       # the last fifteen minutes
aws logs tail /aws/lambda/FUNCTION --filter-pattern ERROR
```

### Finding your own resources

```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Workshop,Values=NL-2026 \
  --query 'ResourceTagMappingList[].ResourceARN' \
  --output table
```

Only works because `main.tf` tags everything. It is the practical argument for a tagging convention.

---

## Links

| What | Link |
|---|---|
| AWS provider reference | https://registry.terraform.io/providers/hashicorp/aws/latest/docs |
| Archive provider | https://registry.terraform.io/providers/hashicorp/archive/latest/docs |
| Terraform language docs | https://developer.hashicorp.com/terraform/language |
| Terraform CLI docs | https://developer.hashicorp.com/terraform/cli |
| AWS CLI command reference | https://awscli.amazonaws.com/v2/documentation/api/latest/index.html |
| Lambda Python runtime | https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html |
| API Gateway v2 payload format | https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html |

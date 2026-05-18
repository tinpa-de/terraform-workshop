# Initialize new environment
If a new AWS environment should be setup for terraform deployment, first of all a terraform backend is needed. 
This is done by creating a S3 bucket to store the state and also a DynamoDB table to be able to lock that state.

## Step-by-step
### Setup AWS Account access
With your local user log in to the AWS Account using `aws configure sso --profile <profile-name>`.
After successfully completing the setup, you should be able to list all existing buckets in the Account by running `aws s3 ls`.

### Run initial Terraform environment setup
Please set the values in the [default.auto.tfvars](default.auto.tfvars) file.

|Variable| Description                                                           |
|-- |-----------------------------------------------------------------------|
| region_backend | The region in which the terraform backend should be hosted.           |
| backend_bucket_name | The name of the bucket which is created to store the terraform state. |

After that, from the initialize-environment directory run sequentially:
* `terraform init -reconfigure`
* `terraform apply`

### Setup GitHub runner roles
To be able to deploy using GitHub runners, we need to setup the roles. In the [variables](../terraform/variables) folder we need to set a new backend for our created environment. Here we can just create a file `backend.tfvars` and enter the previous used parameters.<br>
Next, we should create a variables file for the new environment. In the [variables](../terraform/variables) directory a file `config.tfvars` should be created and be filled with all present variables, which can be retreived from another environment variables file.

After filling these two, we can execute the terraform code to deploy the initial rights as follows:
* Go to [terraform](../terraform) directory
* `terraform init -backend-config=variables/backend.tfvars`
* `terraform apply -var-file=variables/config.tfvars`

The rights should be initialized.
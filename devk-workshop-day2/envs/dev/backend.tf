# Remote State – baut auf dem Backend aus Tag 1 auf.
#
# Tragt hier euren persönlichen Namen ein (gleicher Wert wie in Tag 1):
#   dynamodb_table = "terraform-state-lock-NAME"
#
# Bucket-Name anpassen, falls euer Bucket einen anderen Namen hat:
#   terraform init -backend-config="bucket=terraform-state-nl-devk-XXXX"

terraform {
  backend "s3" {
    bucket         = "terraform-state-nl-devk"
    key            = "day2/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-state-lock-TEST"   # ← gleicher Name wie in Tag 1
    encrypt        = true
  }
}

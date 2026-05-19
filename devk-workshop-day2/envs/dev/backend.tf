# Remote State – baut auf dem Backend aus Tag 1 auf.
#
# Der S3-Bucket und die DynamoDB-Tabelle wurden an Tag 1 in
# initialize-lock-db/ angelegt. Hier nutzen wir beides weiter,
# nur mit einem anderen Key für den Tag-2-State.
#
# Bucket-Name anpassen (euer persönlicher Suffix aus Tag 1):
#   terraform init -backend-config="bucket=terraform-state-nl-devk-XXXX"
# Oder direkt hier eintragen und terraform init ausführen.

terraform {
  backend "s3" {
    bucket         = "terraform-state-nl-devk"
    key            = "day2/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "devk-tfstate-lock"
    encrypt        = true
  }
}

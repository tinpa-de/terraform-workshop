# Backend-Konfiguration für Remote State.
# Im Workshop kann zunächst lokal gearbeitet werden; in Produktion -> S3 + DynamoDB.
#
# Auskommentiert lassen, falls der Bucket aus Tag 1 noch nicht angelegt wurde.
#
# terraform {
#   backend "s3" {
#     bucket         = "devk-tfstate-XXXX"
#     key            = "day2/dev/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "devk-tfstate-lock"
#     encrypt        = true
#   }
# }

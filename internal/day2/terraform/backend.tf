# Local state - terraform.tfstate is written into this directory.
#
# That is fine for a workshop and terrible for a team: the file lives on one
# laptop, it is not locked against concurrent writes, and it holds every
# attribute of every resource in plain text. In production this file would
# instead configure a remote backend, e.g.:
#
#   terraform {
#     backend "s3" {
#       bucket       = "nl-terraform-state"
#       key          = "feedback/dev/terraform.tfstate"
#       region       = "eu-west-1"
#       use_lockfile = true
#     }
#   }
#
# See docs/best-practices.md.

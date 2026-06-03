# ---------------------------------------------------------------------------
# Aufgabe: Storage-Modul implementieren
#
# Ziel: Einen sicheren S3-Bucket für Schadensdokumente anlegen.
#
# Die Variablen und Outputs sind bereits vorgegeben (variables.tf / outputs.tf).
# Eure Aufgabe: Alle Ressourcen in dieser Datei implementieren.
#
# Anforderungen:
#   1. S3-Bucket mit dem Namen: "${var.project}-${var.environment}-claims-jasper"
#   2. Versionierung aktivieren (damit Dokumente nie verloren gehen)
#   3. Server-seitige Verschlüsselung mit AES256
#   4. Alle öffentlichen Zugriffe blockieren (vier Flags, alle true)
#   5. BONUS: Lifecycle-Regel – alte Versionen nach 90 Tagen löschen
#
# Hilfreiche Doku:
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration
#
# Tipp: Fang mit dem Bucket an, dann füge die anderen Ressourcen Schritt für
#       Schritt hinzu. Jede Ressource referenziert den Bucket über seine ID:
#         bucket = aws_s3_bucket.claims.id
# ---------------------------------------------------------------------------

# TODO 1: S3-Bucket anlegen
resource "aws_s3_bucket" "claims" {
  bucket = "${var.project}-${var.environment}-claims-jasper"
  tags = var.tags
}

# TODO 2: Versionierung aktivieren
resource "aws_s3_bucket_versioning" "claims" {
  bucket = aws_s3_bucket.claims.id
  versioning_configuration {
    status = "Enabled"
  }
}

# TODO 3: Serverseitige Verschlüsselung (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "claims" {
  bucket = aws_s3_bucket.claims.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TODO 4: Öffentlichen Zugriff blockieren
resource "aws_s3_bucket_public_access_block" "claims" {
  bucket = aws_s3_bucket.claims.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# TODO 5 (BONUS): Lifecycle-Regel für alte Versionen
resource "aws_s3_bucket_lifecycle_configuration" "claims" {
  bucket = aws_s3_bucket.claims.id
  rule {
    id = "jasper_bucket_lifecycle_configuration"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

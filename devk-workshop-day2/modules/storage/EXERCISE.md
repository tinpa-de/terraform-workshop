# Aufgabe: Storage-Modul implementieren

## Kontext

Ihr baut das Backend für ein Schadensmeldungs-Portal.
Versicherungsnehmer laden Schadensdokumente (Fotos, PDFs) hoch. Diese müssen
sicher gespeichert, versioniert und verschlüsselt sein.

Euer Auftrag: Das Terraform-Modul `modules/storage` implementieren.

---

## Was ihr kennt (Tag 1 Recap)

- Ihr wisst, wie ein Terraform-Modul aufgebaut ist: `variables.tf`, `main.tf`, `outputs.tf`
- Ihr habt gestern S3-Ressourcen gebaut: Bucket, Public Access Block, Bucket Policy
- Heute geht es einen Schritt weiter: Versionierung, Verschlüsselung, Lifecycle

Die Interfaces sind bereits vorgegeben — ihr müsst nur `main.tf` befüllen.

---

## Anforderungen

| # | Was | Warum |
|---|-----|-------|
| 1 | **S3-Bucket** mit Name `{project}-{environment}-claims-{suffix}` | Eindeutiger Name im globalen S3-Namespace |
| 2 | **Versionierung** aktivieren | Dokumente dürfen nicht verloren gehen |
| 3 | **Verschlüsselung** mit AES256 | Daten at-rest verschlüsseln (DSGVO) |
| 4 | **Public Access Block** (alle 4 Flags = true) | Bucket darf nie öffentlich zugänglich sein |
| 5 | **Lifecycle-Regel** (BONUS) | Alte Versionen nach 90 Tagen löschen – Kostensparen |

---

## Wo anfangen?

```
modules/storage/
├── main.tf        ← Eure Aufgabe (TODO-Kommentare sind Platzhalter)
├── variables.tf   ← bereits fertig, nur lesen
└── outputs.tf     ← bereits fertig, nur lesen
```

1. Öffnet `variables.tf` – schaut, was euch zur Verfügung steht
2. Öffnet `outputs.tf` – schaut, was das Modul nach außen geben soll
3. Implementiert `main.tf` Ressource für Ressource (Reihenfolge wie in den TODOs)

---

## Hilfreiche Links

- [aws_s3_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [aws_s3_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning)
- [aws_s3_bucket_server_side_encryption_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration)
- [aws_s3_bucket_public_access_block](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block)
- [aws_s3_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration)

---

## Testen

Sobald ihr fertig seid (oder zumindest den Bucket + eine Ressource habt):

```bash
cd envs/dev
terraform init
terraform validate          # Syntaxfehler aufdecken
terraform plan -target=module.storage
terraform apply -target=module.storage
```

Schnelltest:
```bash
BUCKET=$(terraform output -raw s3_bucket)
echo "Testdokument" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://${BUCKET}/test.txt
aws s3 ls s3://${BUCKET}/

# Versionierung prüfen (solltet ihr "Enabled" sehen)
aws s3api get-bucket-versioning --bucket ${BUCKET}
```

---

## Lösung

Falls ihr nicht weiterkommt: `solutions/storage/main.tf`
Aber erst wirklich versuchen! 💪

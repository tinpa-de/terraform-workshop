# DEVK Terraform Workshop – Tag 2

Heute baut ihr das Backend eines Schadensmeldungs-Portals. Versicherungsnehmer können Schäden online melden, Dokumente hochladen und den Status abrufen.

Am Ende des Tages habt ihr:
- Ein Storage-Modul selbst in Terraform implementiert
- Eine PostgreSQL-Datenbank auf RDS deployed
- Zwei Lambda-Funktionen über Terraform provisioniert
- Ein API Gateway mit drei REST-Endpunkten in Betrieb genommen

---

## Use Case: Schadensmeldungs-Portal

```
                   ① POST /claims    ┌──────────────────┐
   ┌─────────┐ ──────────────────►  │   API Gateway    │
   │ Browser │                      │   + API Lambda   │──── ② INSERT ────► ┌──────────────┐
   └────┬────┘ ◄──────────────────  │                  │                    │ RDS Postgres │
        │        ③ { upload_url }   └──────────────────┘                    └──────▲───────┘
        │                                                                           │
        │ ④ PUT (presigned URL)     ┌──────────┐   ⑤ ObjectCreated   ┌────────────┴────────┐
        └──────────────────────────►│    S3    │──────────────────►  │  Processor Lambda   │
                                    └──────────┘                      └─────────────────────┘
```

---

## Bezug zu Tag 1

Heute wendet ihr dieselben Konzepte wie gestern an – mit mehr Services und einer echten Anwendung:

| Tag 1 | Tag 2 |
|-------|-------|
| Einfache S3-Ressourcen | S3 mit Versionierung, Verschlüsselung, Lifecycle |
| Ein eigenes Modul gebaut | Modul selbst implementieren + vorgefertigte Module nutzen |
| Remote State eingerichtet | Remote State weiter nutzen (gleicher Bucket, neuer Key) |
| Provider, Variablen, Outputs | Alles davon – plus IAM, Lambda, RDS, API Gateway |

---

## AWS-Services heute

| Service | Was macht es? | Terraform-Ressource |
|---------|---------------|---------------------|
| **S3** | Objektspeicher, unbegrenzt skalierbar | `aws_s3_bucket` |
| **RDS** | Verwaltete relationale Datenbank | `aws_db_instance` |
| **Lambda** | Code ohne Server ausführen, event-getriggert | `aws_lambda_function` |
| **API Gateway** | HTTP-API-Endpunkte verwalten | `aws_apigatewayv2_api` |
| **Security Group** | Firewall-Regeln für AWS-Ressourcen | `aws_security_group` |
| **IAM Role** | Berechtigungen für AWS-Services | `aws_iam_role` |

---

## Voraussetzungen

Vor dem ersten `terraform init` bitte prüfen:

```bash
# 1. Terraform-Version
terraform version   # sollte >= 1.6 sein

# 2. AWS-Credentials (Session aus Tag 1 erneuern falls abgelaufen)
aws sso login --profile workshop
export AWS_PROFILE=workshop
aws sts get-caller-identity   # muss eine Account-ID zurückgeben

# 3. Region prüfen
aws configure get region   # sollte eu-central-1 sein

# 4. Default-VPC (RDS braucht eine Subnet Group)
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text
# Wenn "None" zurückkommt: aws ec2 create-default-vpc
```

> **Wichtig:** Am Ende des Workshops bitte `terraform destroy` ausführen – RDS verursacht sonst laufende Kosten.

---

## Setup

```bash
cd envs/dev
```

Öffnet `backend.tf` und tragt euren persönlichen Namen ein – denselben, den ihr in Tag 1 für die DynamoDB-Tabelle verwendet habt:

```hcl
dynamodb_table = "terraform-state-lock-NAME"   # ← euer Name aus Tag 1
```

Dann:

```bash
# tfvars liegt bereits bereit – Passwort anpassen:
cat terraform.tfvars

# Remote State aus Tag 1 weiterverwenden.
# Bucket-Namen anpassen, falls euer Bucket einen anderen Namen hat:
# terraform init -backend-config="bucket=terraform-state-nl-devk-XXXX"
terraform init
```

---

## Überblick: Was ist vorgegeben, was baut ihr selbst?

```
modules/
├── storage/     ← IHR implementiert main.tf  (Aufgabe Part 1)
├── database/    ← vorgegeben (lesenswert)
├── processor/   ← vorgegeben
└── api/         ← vorgegeben

envs/dev/
└── main.tf      ← IHR füllt TODO A aus      (Aufgabe Part 1)
```

**Euer Workflow für jeden Schritt:**

```
.tf-Datei schreiben  →  terraform validate  →  terraform plan  →  terraform apply
```

Führt `terraform validate` und `terraform plan` nach jeder neuen Ressource aus. So seht ihr Fehler früh und versteht, was Terraform vorhat.

---

## Part 1: Storage-Modul + Datenbank

### Schritt 1.1 – Storage-Modul implementieren

**Ziel:** Implementiert `modules/storage/main.tf`. Das Modul soll einen S3-Bucket mit Versionierung, serverseitiger Verschlüsselung und Public-Access-Block anlegen.

Lest zuerst `modules/storage/EXERCISE.md` – dort stehen alle Anforderungen. Lest außerdem `modules/storage/variables.tf` und `modules/storage/outputs.tf`, damit ihr wisst, welche Inputs und Outputs das Modul hat.

```bash
# Nach jeder neuen Ressource testen:
terraform validate
terraform plan -target=module.storage
```

> Lösung bei Bedarf: `solutions/storage/main.tf`

<details>
<summary>Hinweis – Ressource 1: S3-Bucket</summary>

```hcl
resource "aws_s3_bucket" "claims" {
  bucket = "${var.project}-${var.environment}-claims-${var.suffix}"
  tags   = var.tags
}
```

Der Bucket-Name muss global eindeutig sein. Der Suffix aus `random_id` sorgt dafür.

</details>

<details>
<summary>Hinweis – Ressource 2: Versionierung</summary>

```hcl
resource "aws_s3_bucket_versioning" "claims" {
  bucket = aws_s3_bucket.claims.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

</details>

<details>
<summary>Hinweis – Ressource 3: Verschlüsselung</summary>

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "claims" {
  bucket = aws_s3_bucket.claims.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

</details>

<details>
<summary>Hinweis – Ressource 4: Public Access Block</summary>

```hcl
resource "aws_s3_bucket_public_access_block" "claims" {
  bucket = aws_s3_bucket.claims.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

</details>

**Terraform-Dokumentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block

---

### Schritt 1.2 – Storage deployen und testen

**Ziel:** Das Storage-Modul in `envs/dev/main.tf` einbinden (TODO A) und deployen.

Öffnet `envs/dev/main.tf` und schaut euch die TODO-Kommentare an. Schaut euch außerdem `modules/storage/outputs.tf` an – welche Outputs gibt das Modul zurück? Diese werden später von `processor` und `api` benötigt.

```bash
terraform apply -target=module.storage
```

**Überprüfen:**

```bash
BUCKET=$(terraform output -raw s3_bucket)

# Upload testen
echo "Testdokument" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://${BUCKET}/policies/POL-99999/test.txt
aws s3 ls s3://${BUCKET}/policies/POL-99999/

# Versionierung prüfen
aws s3api get-bucket-versioning --bucket ${BUCKET}
# Erwartet: { "Status": "Enabled" }
```

> `-target` ist normalerweise ein Code Smell. Wir nutzen es heute bewusst, um die Infrastruktur schrittweise aufzubauen. Im Alltag: `terraform apply` ohne `-target`.

---

### Schritt 1.3 – Datenbank starten

**Ziel:** Die RDS-Instanz deployen.

```bash
terraform apply -target=module.database
```

Das dauert ca. 8–10 Minuten. Nutzt die Zeit, um `modules/database/main.tf` zu lesen.

**Diskussionspunkte während der Wartezeit:**
- Warum `skip_final_snapshot = true`? (Wann ist das gefährlich?)
- Warum ist `db_password` als `sensitive = true` markiert?
- `publicly_accessible = true` – warum ist das hier eine Vereinfachung, und wie würde es in Produktion aussehen?
- Was ist eine Subnet Group und warum braucht RDS das?

---

## Part 2: Application Layer deployen und verstehen

### Schritt 2.1 – Guided Tour: Processor-Modul

**Ziel:** Verstehen, wie Lambda per Terraform provisioniert wird und wie S3-Events funktionieren.

Lest gemeinsam `modules/processor/main.tf`. Was passiert hier?

1. `data.archive_file` – Source-Code wird gezippt
2. `aws_iam_role` + Policy – Lambda bekommt Berechtigungen (S3 lesen, RDS erreichen)
3. `aws_lambda_function` – Python-Funktion, event-getriggert
4. `aws_s3_bucket_notification` – Bucket ruft Lambda bei jedem Upload auf

Schaut auch in `lambda-src/processor/handler.py` – was macht der Code konkret?

---

### Schritt 2.2 – Processor deployen und testen

**Ziel:** Die Processor-Lambda deployen und mit einem echten S3-Upload testen.

```bash
terraform apply -target=module.processor
```

**Überprüfen:**

```bash
# Upload simuliert eine Schadensmeldung
echo "Schadensfoto Mock" > /tmp/schaden.jpg
aws s3 cp /tmp/schaden.jpg \
  s3://$(terraform output -raw s3_bucket)/policies/POL-12345/schaden.jpg

# Lambda-Logs live verfolgen (Strg+C zum Beenden)
aws logs tail $(terraform output -raw processor_log_group) --follow
```

Ihr solltet sehen: Lambda empfängt das S3-Event, legt die Tabelle an und schreibt einen Eintrag.

---

### Schritt 2.3 – API deployen

**Ziel:** Das gesamte Setup vervollständigen.

```bash
# Ohne -target – deployed jetzt alles
terraform apply
```

Schaut kurz in `modules/api/main.tf`: API Gateway v2 (HTTP API), 3 Routen, Lambda-Integration.

Und in `lambda-src/api/handler.py`: Wie werden Routen gematcht? Wie wird die presigned URL generiert?

---

### Schritt 2.4 – End-to-End testen

**Ziel:** Den vollständigen Claim-Flow vom POST bis zum S3-Upload durchspielen.

```bash
API_URL=$(terraform output -raw api_url)

# Schadensmeldung anlegen
curl -s -X POST ${API_URL}/claims \
  -H "Content-Type: application/json" \
  -d '{
    "policy_number": "POL-12345",
    "claim_type":    "motor",
    "description":   "Parkschaden auf dem Aldi-Parkplatz"
  }' | jq

# Alle Claims auflisten
curl -s ${API_URL}/claims | jq

# Einzelnen Claim abrufen (ID aus der POST-Antwort einsetzen)
curl -s ${API_URL}/claims/CLM-XXXXXXXXXX | jq
```

**Presigned URL – der Browser-Upload-Flow:**

Im POST-Response ist eine `upload_url`. Das ist eine AWS Presigned URL – sie erlaubt einem Browser, direkt nach S3 zu uploaden, ohne eigene AWS-Credentials zu haben. Schaut in `lambda-src/api/handler.py` nach, wie sie erzeugt wird.

```bash
# Presigned URL aus der POST-Antwort nehmen und damit direkt hochladen:
UPLOAD_URL="<upload_url aus dem POST-Response>"
curl -X PUT "${UPLOAD_URL}" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/tmp/schaden.jpg
```

**Überprüfen:** Prozessor-Logs checken – wurde das Dokument registriert?

```bash
aws logs tail $(terraform output -raw processor_log_group) --follow
```

---

## Aufräumen

> **Wichtig:** Bitte am Ende des Workshops aufräumen – RDS verursacht sonst laufende Kosten.

```bash
# S3-Bucket muss leer sein, sonst schlägt destroy fehl
aws s3 rm s3://$(terraform output -raw s3_bucket) --recursive

terraform destroy
```

---

## Best Practices

Was in diesem Setup bewusst vereinfacht ist und wie man es produktionsreif machen würde – Leitfaden: `docs/best-practices.md`

| Workshop-Vereinfachung | Produktion |
|------------------------|-----------|
| `publicly_accessible = true` (RDS) | `false` + Lambda in VPC + private Subnets + NAT |
| RDS Security Group offen (0.0.0.0/0) | Security Group Referenzen auf Lambda-SGs |
| `db_password` in tfvars | AWS Secrets Manager + `random_password` |
| `skip_final_snapshot = true` | `false` + Snapshot-Name pflegen |
| Lambda-Code im selben Repo | Eigene Pipeline + S3-Versionierung |
| API ohne Auth | Cognito / API Keys / IAM Auth |
| Single-AZ RDS | Multi-AZ + Read Replica |
| Default VPC | Eigene VPC mit privaten Subnets + NAT |
| Kein `.terraform.lock.hcl` | Im Git einchecken: `terraform providers lock` |

---

## Wenn etwas schief geht

Siehe `docs/troubleshooting.md` und `docs/cheatsheet.md`.

Häufige Stolpersteine:
- **Default VPC fehlt**: `aws ec2 create-default-vpc`
- **terraform.tfvars fehlt**: `cp terraform.tfvars.example terraform.tfvars`
- **Lambda Layer nicht gefunden**: Aktuelle ARN auf https://api.klayers.cloud prüfen

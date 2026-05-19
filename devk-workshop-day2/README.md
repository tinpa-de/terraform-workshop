# DEVK Terraform Workshop – Tag 2

## Use Case: Schadensmeldungs-Portal (Claims Intake)

Wir bauen das Backend für ein Portal, mit dem Versicherungsnehmer Schäden
online melden können. Dokumente werden in **S3** abgelegt, eine **Lambda-Funktion**
wird beim Upload getriggert, extrahiert Metadaten und schreibt sie in eine
**PostgreSQL-Datenbank (RDS)**. Eine zweite Lambda hinter einem **API Gateway**
bietet REST-Endpoints zum Anlegen und Abfragen von Schadensmeldungen.

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

Gestern habt ihr die Grundlagen von Terraform kennengelernt:

| Tag 1 | Tag 2 |
|-------|-------|
| Einfache S3-Ressourcen | S3 mit Versionierung, Verschlüsselung, Lifecycle |
| Ein eigenes Modul gebaut | Modul selbst implementieren + vorgefertigte Module nutzen |
| Remote State eingerichtet | Remote State weiter nutzen (gleicher Bucket, neuer Key) |
| Provider, Variablen, Outputs | Alles davon – plus IAM, Lambda, RDS, API Gateway |

Ihr werdet heute genau dieselben Konzepte anwenden – nur mit mehr Services und
einer echten Anwendung dahinter.

---

## Voraussetzungen

Vor dem ersten `terraform init` bitte prüfen:

```bash
# 1. Terraform-Version
terraform version   # sollte >= 1.6 sein

# 2. AWS-Credentials
aws sts get-caller-identity   # muss eine Account-ID zurückgeben

# 3. Region prüfen
aws configure get region   # sollte eu-central-1 sein

# 4. Default-VPC (RDS braucht eine Subnet Group)
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text
# Wenn "None" zurückkommt: aws ec2 create-default-vpc
```

> ⚠️ **Wichtig:** Am Ende des Workshops bitte `terraform destroy` ausführen –
> RDS läuft sonst 24/7 und verursacht Kosten.

---

## Setup

```bash
cd envs/dev

# tfvars liegt bereits bereit – Passwort anpassen:
# (oder per Umgebungsvariable: export TF_VAR_db_password="...")
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
├── database/    ← vorgegeben (zu komplex für den Einstieg, aber lesenswert)
├── processor/   ← vorgegeben
└── api/         ← vorgegeben

envs/dev/
└── main.tf      ← IHR füllt die TODOs aus    (Aufgabe Part 1 + 2)
```

---

## Part 1 (10:00 – 12:00): Storage-Modul + Integration

### Kontext: AWS-Services im Überblick (10:00 – 10:15)

Kurze Vorstellung der heutigen Services – nur das Nötigste zum Verstehen:

| Service | Was macht es? | Terraform-Ressource |
|---------|---------------|---------------------|
| **S3** | Objektspeicher, unbegrenzt skalierbar | `aws_s3_bucket` |
| **RDS** | Verwaltete relationale Datenbank | `aws_db_instance` |
| **Lambda** | Code ohne Server ausführen, event-getriggert | `aws_lambda_function` |
| **API Gateway** | HTTP-API-Endpunkte verwalten | `aws_apigatewayv2_api` |
| **Security Group** | Firewall-Regeln für AWS-Ressourcen | `aws_security_group` |
| **IAM Role** | Berechtigungen für AWS-Services | `aws_iam_role` |

### Schritt 1.1 – Aufgabe: Storage-Modul implementieren (10:15 – 11:00)

Öffnet `modules/storage/EXERCISE.md` – dort steht alles, was ihr wissen müsst.

**Kurzfassung:**
- Lest `modules/storage/variables.tf` und `modules/storage/outputs.tf`
- Implementiert `modules/storage/main.tf` (TODO-Kommentare als Leitfaden)
- Ziel: S3-Bucket mit Versionierung, Verschlüsselung, Public Access Block

```bash
# Zwischentesten nach jeder Ressource:
terraform validate
terraform plan -target=module.storage
```

> Lösung bei Bedarf: `solutions/storage/main.tf`

### Schritt 1.2 – Storage deployen + testen (11:00 – 11:20)

```bash
terraform apply -target=module.storage
```

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

> 💡 `-target` ist normalerweise ein Code Smell. Wir nutzen es heute bewusst,
> um die Infrastruktur Schritt für Schritt aufzubauen. Im Alltag: einfach
> `terraform apply` über alles.

### Schritt 1.3 – TODO B: Module verdrahten (11:20 – 11:35)

Öffnet `envs/dev/main.tf`. Beim `module "database"` gibt es ein **TODO B**:

```hcl
allowed_security_group_ids = [
  # TODO: Welche Security Groups müssen hier rein?
]
```

Schaut euch `modules/processor/outputs.tf` und `modules/api/outputs.tf` an.
Welcher Output liefert die Security-Group-ID? Tragt die richtigen Referenzen ein.

> Lösung: `solutions/main.tf`

### Schritt 1.4 – Datenbank starten (11:35 – 12:00)

```bash
terraform apply -target=module.database
```

⏳ Das dauert ~8–10 Minuten. Nutzt die Zeit, um `modules/database/main.tf`
zu lesen.

**Diskussionspunkte während der Wartezeit:**
- Warum `skip_final_snapshot = true`? (Wann ist das gefährlich?)
- Warum ist `db_password` als `sensitive = true` markiert?
- `publicly_accessible = false` – wie kommt die Lambda trotzdem ran?
- Was ist ein Subnet Group und warum braucht RDS das?

---

## Part 2 (13:00 – 14:45): Application Layer deployen + verstehen

### Schritt 2.1 – Guided Tour: Processor-Modul (13:00 – 13:20)

Gemeinsam lesen wir `modules/processor/main.tf`.

Was passiert hier alles?
1. `data.archive_file` – Source-Code wird gezippt
2. `aws_iam_role` + Policy – Lambda bekommt Berechtigungen (S3 lesen, RDS erreichen)
3. `aws_lambda_function` – Python-Funktion in der VPC
4. `aws_s3_bucket_notification` – Bucket ruft Lambda bei jedem Upload

Schaut auch in `lambda-src/processor/handler.py` – was macht der Code konkret?

### Schritt 2.2 – Processor deployen + testen (13:20 – 13:45)

```bash
terraform apply -target=module.processor
```

```bash
# Upload simuliert eine Schadensmeldung
echo "Schadensfoto Mock" > /tmp/schaden.jpg
aws s3 cp /tmp/schaden.jpg \
  s3://$(terraform output -raw s3_bucket)/policies/POL-12345/schaden.jpg

# Lambda-Logs live verfolgen (Strg+C zum Beenden)
aws logs tail $(terraform output -raw processor_log_group) --follow
```

Ihr solltet sehen: Lambda empfängt das S3-Event, legt die Tabelle an und
schreibt einen Eintrag.

### Schritt 2.3 – API deployen (13:45 – 14:00)

```bash
# Ohne -target – vervollständigt jetzt alles
terraform apply
```

Kurzer Blick in `modules/api/main.tf`: API Gateway v2 (HTTP API),
3 Routen, Lambda-Integration.

Und `lambda-src/api/handler.py`: Wie werden Routen gematcht? Wie wird
die presigned URL generiert?

### Schritt 2.4 – End-to-End testen (14:00 – 14:45)

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

Im POST-Response ist eine `upload_url`. Das ist eine AWS Presigned URL –
sie erlaubt einem Browser, direkt nach S3 zu uploaden, ohne eigene
AWS-Credentials zu haben. Schaut im `api/handler.py` nach, wie sie erzeugt wird.

```bash
# Presigned URL aus der POST-Antwort nehmen und damit direkt hochladen:
UPLOAD_URL="<upload_url aus dem POST-Response>"
curl -X PUT "${UPLOAD_URL}" \
  -H "Content-Type: image/jpeg" \
  --data-binary @/tmp/schaden.jpg
```

Danach: Prozessor-Logs checken – wurde das Dokument registriert?

---

## Aufräumen (WICHTIG!)

```bash
# S3-Bucket muss leer sein, sonst schlägt destroy fehl
aws s3 rm s3://$(terraform output -raw s3_bucket) --recursive

terraform destroy
```

---

## Best Practices Block (15:00 – 15:30)

Wir diskutieren, was in diesem Setup **bewusst vereinfacht** ist und wie
man es produktionsreif machen würde. Leitfaden: `docs/best-practices.md`

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
- **Lambda kann RDS nicht erreichen**: Security Group in TODO B korrekt?
- **Lambda Layer nicht gefunden**: Aktuelle ARN auf https://api.klayers.cloud prüfen

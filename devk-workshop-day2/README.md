# DEVK Terraform Workshop – Tag 2

## Use Case: Schadensmeldungs-Portal (Claims Intake)

Wir bauen das Backend für ein Portal, mit dem Versicherungsnehmer Schäden
online melden können. Dokumente werden in **S3** abgelegt, eine **Lambda**
wird beim Upload getriggert, extrahiert Metadaten und schreibt sie in eine
**PostgreSQL-Datenbank (RDS)**. Eine zweite Lambda hinter einem **API Gateway**
bietet REST-Endpoints zum Anlegen und Abfragen von Schadensmeldungen.

```
                            ┌─────────────────┐
                            │   API Gateway   │  POST /claims
                            │   (HTTP API)    │  GET  /claims
                            └────────┬────────┘
                                     │
                                     ▼
   ┌──────────┐      Upload     ┌─────────────┐    INSERT    ┌──────────┐
   │ Browser  │ ──────────────► │  API Lambda │ ───────────► │   RDS    │
   └──────────┘                 └─────────────┘              │ Postgres │
        │                                                    └─────▲────┘
        │ presigned PUT                                            │
        ▼                                                          │ INSERT
   ┌──────────┐                                                    │
   │    S3    │ ───── ObjectCreated ────► ┌─────────────────┐ ─────┘
   │  Bucket  │                           │ Processor Lambda │
   └──────────┘                           └─────────────────┘
```

---

## Voraussetzungen

- AWS-CLI konfiguriert (`aws configure` oder SSO)
- Terraform >= 1.6 (`terraform version`)
- Zugriff auf den Workshop-AWS-Account
- Region: `eu-central-1`

> ⚠️ **Wichtig:** Am Ende des Workshops bitte `terraform destroy` ausführen,
> damit keine Kosten entstehen (RDS läuft sonst 24/7).

---

## Setup

```bash
cd envs/dev

# tfvars vorbereiten
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars öffnen und db_password setzen!

terraform init
```

---

## Part 1 (10:00 – 12:00): Foundation – Storage & Database

In diesem Teil legen wir die Basis-Infrastruktur an: einen S3-Bucket für die
Schadensdokumente und eine RDS PostgreSQL-Datenbank für die Metadaten.

### Schritt 1.1 – Storage prüfen

Schaut euch das Modul `modules/storage` an. Was fällt auf?

- Versioning ist aktiviert – warum?
- Public Access Block – was passiert ohne ihn?
- Lifecycle Rule – wofür?

### Schritt 1.2 – Nur Storage anlegen

Wir wollen erst den Bucket sehen, bevor wir die DB anwerfen (RDS dauert ~10 Min).

```bash
terraform plan -target=module.storage
terraform apply -target=module.storage
```

> 💡 `-target` ist normalerweise ein Code Smell. Hier nutzen wir es bewusst, um
> didaktisch Schritt für Schritt vorzugehen. In normalen Workflows: einfach
> `terraform apply` über das Ganze.

Bucket-Name aus den Outputs notieren:

```bash
terraform output s3_bucket
```

Test:

```bash
echo "hallo" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://$(terraform output -raw s3_bucket)/test.txt
aws s3 ls s3://$(terraform output -raw s3_bucket)/
```

### Schritt 1.3 – Datenbank anlegen

```bash
terraform apply -target=module.database
```

⏳ Das dauert ~8–10 Minuten. Nutzt die Zeit, um euch die `modules/database`-Files
anzuschauen.

**Diskussionspunkte währenddessen:**
- Warum `skip_final_snapshot = true`? Wann ist das gefährlich?
- Warum ist `db_password` als `sensitive = true` markiert?
- Wie würdet ihr das Passwort in Produktion handhaben?

### Schritt 1.4 – Verbindung testen (optional, nur wenn Bastion vorhanden)

Direktverbindung zu RDS aus dem Public Internet geht nicht (`publicly_accessible = false`).
Das ist gewollt – die DB ist nur aus der VPC erreichbar. Im Test stellen wir das
gleich über die Lambda fest.

---

## Part 2 (13:00 – 14:45): Application Layer – Lambda & API

Jetzt kommen die Anwendungs-Bausteine: die Processor-Lambda mit S3-Trigger und
die API-Lambda hinter API Gateway.

### Schritt 2.1 – Processor-Lambda deployen

```bash
terraform apply -target=module.processor
```

Was passiert hier alles?
1. Source-Code wird gezippt (`archive_file`)
2. IAM-Rolle für Lambda wird angelegt
3. Lambda-Funktion in der VPC (damit sie an RDS rankommt)
4. S3-Event-Notification verknüpft Bucket → Lambda

### Schritt 2.2 – Trigger testen

```bash
# Upload simuliert eine Schadensmeldung
echo "Schadensfoto Mock" > /tmp/schaden.jpg
aws s3 cp /tmp/schaden.jpg \
  s3://$(terraform output -raw s3_bucket)/policies/POL-12345/schaden.jpg

# Logs der Lambda anschauen (Strg+C zum Beenden)
aws logs tail $(terraform output -raw processor_log_group) --follow
```

Ihr solltet sehen, dass die Lambda das Event empfangen, die Tabelle angelegt
und einen Eintrag geschrieben hat.

### Schritt 2.3 – API deployen

```bash
terraform apply
```

(Ohne `-target` – das vervollständigt jetzt alles.)

### Schritt 2.4 – API testen

```bash
API_URL=$(terraform output -raw api_url)

# Claim anlegen
curl -X POST $API_URL/claims \
  -H "Content-Type: application/json" \
  -d '{
    "policy_number": "POL-12345",
    "claim_type": "motor",
    "description": "Parkschaden auf dem Aldi-Parkplatz"
  }'

# Alle Claims auflisten
curl $API_URL/claims | jq

# Einzelnen Claim abrufen (ID aus der vorherigen Antwort einsetzen)
curl $API_URL/claims/CLM-XXXXXXXXXX | jq
```

### Schritt 2.5 – End-to-End

Im Response von `POST /claims` ist eine `upload_url` (presigned URL).
Damit könnte ein Browser-Frontend direkt nach S3 hochladen, ohne Credentials
zu kennen. Schaut euch im Handler-Code an, wie das gemacht wird.

---

## Aufräumen (WICHTIG!)

```bash
# S3-Bucket muss leer sein, sonst meckert destroy
aws s3 rm s3://$(terraform output -raw s3_bucket) --recursive

terraform destroy
```

---

## Wenn etwas schief geht

Siehe `docs/troubleshooting.md` und `docs/cheatsheet.md`.

## Best Practices Block (15:00)

Wir diskutieren danach, was in diesem Setup **bewusst nicht produktionsreif**
ist und wie man es besser machen würde:

- DB-Passwort in tfvars → **Secrets Manager**
- `skip_final_snapshot = true` → **false + Snapshot-Namen**
- Lambda-Code im selben Repo → **separate Pipeline + Versioning**
- API ohne Auth → **Cognito / IAM Auth / API Keys**
- Single-AZ RDS → **Multi-AZ + Read Replicas**
- Default VPC → **eigene VPC mit Private Subnets + NAT**

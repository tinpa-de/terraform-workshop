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
| Local State genutzt | Local State weiter nutzen |
| Provider, Variablen, Outputs | Alles davon – plus IAM, Lambda, RDS, API Gateway |

---

## AWS-Services heute

| Service | Was macht es? | Terraform-Ressource |
|---------|---------------|---------------------|
| **S3** | Objektspeicher, unbegrenzt skalierbar | `aws_s3_bucket` |
| **RDS** | Verwaltete relationale Datenbank | `aws_db_instance` |
| **Lambda** | Code ohne Server ausführen, event-getriggert | `aws_lambda_function` |
| **API Gateway** | HTTP-API-Endpunkte verwalten | `aws_apigatewayv2_api` |
| **Security Group** | Firewall-Regeln für AWS-Ressourcen | `data "aws_security_group"` (vorab vom Admin erstellt) |
| **IAM Role** | Berechtigungen für AWS-Services | `aws_iam_role` |

---

## Setup

Arbeitet alle vier Schritte der Reihe nach durch. Wenn etwas nicht klappt, fragt bevor ihr weitermacht.

> **Wichtig:** Am Ende des Workshops `terraform destroy` ausführen – RDS läuft sonst weiter und verursacht Kosten.

---

### Schritt 1 – AWS-Session erneuern

SSO-Sessions aus Tag 1 laufen nach einigen Stunden ab. Erneuert die Session und setzt das Profil — die `AWS_PROFILE`-Variable muss in jedem neuen Terminalfenster neu gesetzt werden.

```bash
aws sso login --profile workshop
```

macOS / Linux:
```bash
export AWS_PROFILE=workshop
```

Windows (PowerShell):
```powershell
$env:AWS_PROFILE = "workshop"
```

> Wenn ihr später unerklärliche Authentifizierungsfehler bekommt: das ist meistens der erste Ort, den ihr prüfen solltet.

**Überprüfen:**

```bash
aws sts get-caller-identity
```

Der Befehl muss eine Account-ID zurückgeben. Eine Fehlermeldung bedeutet, die Session ist noch nicht aktiv.

---

### Schritt 2 – Default-VPC prüfen

RDS benötigt eine Subnet Group, die mindestens zwei Availability Zones abdeckt. Wir nutzen dafür den Default-VPC, der in jedem AWS-Account vorhanden sein sollte.

**Überprüfen:**

```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' --output text \
  --region eu-central-1
```

Ihr solltet eine VPC-ID sehen, z.B. `vpc-0a1b2c3d`. Falls die Ausgabe `None` lautet:

```bash
aws ec2 create-default-vpc
```

---

### Schritt 3 – Datenbankpasswort setzen

`terraform.tfvars` liegt bereits bereit, enthält aber einen Platzhalter als Passwort. Öffnet die Datei und setzt ein eigenes Passwort. Die Datei ist in `.gitignore` — sie wird nie ins Repository eingecheckt.

```bash
cd envs/dev
cat terraform.tfvars
```

Öffnet `terraform.tfvars` in eurem Editor und ersetzt `BitteHierEinStarkesPasswortSetzen!` durch ein eigenes Passwort.

**Überprüfen:** Der Platzhalter ist durch ein eigenes Passwort ersetzt.

---

### Schritt 4 – Terraform initialisieren

Lädt die Provider-Plugins herunter und registriert die Module:

```bash
terraform init
```

Ihr solltet sehen: `Terraform has been successfully initialized!` Ihr seid jetzt bereit, mit den Aufgaben zu beginnen.

---

## Überblick: Was ist vorgegeben, was baut ihr selbst?

```
modules/
├── storage/     ← IHR implementiert main.tf  (Aufgabe Part 1)
├── database/    ← IHR implementiert main.tf  (Aufgabe Part 1)
├── processor/   ← vorgegeben
└── api/         ← vorgegeben

envs/dev/
└── main.tf      ← IHR füllt TODO A + TODO B aus  (Aufgabe Part 1)
```

**Euer Workflow für jeden Schritt:**

```
.tf-Datei schreiben  →  terraform validate  →  terraform plan  →  terraform apply
```

Führt `terraform validate` und `terraform plan` nach jeder neuen Ressource aus. So seht ihr Fehler früh und versteht, was Terraform vorhat.

---

## Part 1: Storage-Modul + Datenbank

### Schritt 1.1 – Storage-Modul implementieren

**Ziel:** Implementiert `modules/storage/main.tf`. Das Modul soll einen S3-Bucket mit Versionierung, serverseitiger Verschlüsselung und Public-Access-Block anlegen — so wie es die Anforderungen für ein Schadensmeldungs-Portal erfordern.

Gestern habt ihr bereits S3-Ressourcen gebaut. Heute geht es einen Schritt weiter: Versionierung, Verschlüsselung und Lifecycle.

**Anforderungen:**

| # | Was | Warum |
|---|-----|-------|
| 1 | S3-Bucket mit Name `{project}-{environment}-claims-{suffix}` | Eindeutiger Name im globalen S3-Namespace |
| 2 | Versionierung aktivieren | Dokumente dürfen nicht verloren gehen |
| 3 | Verschlüsselung mit AES256 | Daten at-rest verschlüsseln (DSGVO) |
| 4 | Public Access Block (alle 4 Flags = true) | Bucket darf nie öffentlich zugänglich sein |
| 5 | Lifecycle-Regel (Bonus) | Alte Versionen nach 90 Tagen löschen |

**Wo anfangen:**

1. Öffnet `modules/storage/variables.tf` — was steht euch zur Verfügung?
2. Öffnet `modules/storage/outputs.tf` — was soll das Modul nach außen geben?
3. Implementiert `modules/storage/main.tf` Ressource für Ressource

```bash
# Nach jeder neuen Ressource testen:
terraform validate
terraform plan -target=module.storage
```

> Lösung bei Bedarf: `solutions/storage/main.tf`

<details>
<summary>Hinweis – Ressource 1: S3-Bucket</summary>

`aws_s3_bucket` braucht ein `bucket` Argument für den Namen. Bucket-Namen müssen global eindeutig sein — baut ihn aus den Variablen zusammen, die euch zur Verfügung stehen: `var.project`, `var.environment` und `var.suffix`. Terraform-Stringinterpolation funktioniert so: `"${var.project}-weiterer-text"`. Setzt außerdem `tags = var.tags`.

Schaut in `variables.tf`, welche Variablen das Modul bekommt — ihr müsst nichts hart codieren.

</details>

<details>
<summary>Hinweis – Ressource 2: Versionierung</summary>

`aws_s3_bucket_versioning` braucht ein `bucket` Argument — referenziert euren Bucket mit `aws_s3_bucket.claims.id` (kein hartcodierter Name, sondern eine Ressourcenreferenz). Das ist dasselbe Muster wie in Tag 1.

Innerhalb des Blocks kommt ein `versioning_configuration` Block mit einem `status` Argument. Welchen Wert muss `status` haben, damit Versionierung aktiv ist?

</details>

<details>
<summary>Hinweis – Ressource 3: Verschlüsselung</summary>

`aws_s3_bucket_server_side_encryption_configuration` hat eine verschachtelte Struktur — das ist bei AWS-Ressourcen in Terraform häufig so. Der Aufbau: ein `rule` Block, darin ein `apply_server_side_encryption_by_default` Block, darin das Argument `sse_algorithm`.

Der Wert für serverseitige Verschlüsselung ohne eigene Schlüssel lautet `"AES256"`.

</details>

<details>
<summary>Hinweis – Ressource 4: Public Access Block</summary>

`aws_s3_bucket_public_access_block` hat vier boolean-Argumente, die jeweils einen anderen Aspekt des öffentlichen Zugriffs steuern:

- `block_public_acls`
- `block_public_policy`
- `ignore_public_acls`
- `restrict_public_buckets`

Alle vier sollen `true` sein. Das ist die sichere Standardkonfiguration für einen Bucket, der nie öffentlich zugänglich sein soll — im Gegensatz zu Tag 1, wo ihr Public Access bewusst aufgemacht habt.

</details>

<details>
<summary>Hinweis – Ressource 5 (Bonus): Lifecycle-Regel</summary>

`aws_s3_bucket_lifecycle_configuration` braucht einen `rule` Block mit drei Teilen:
- `id` — ein beliebiger Name für die Regel
- `status = "Enabled"` — damit die Regel aktiv ist
- einen `noncurrent_version_expiration` Block mit dem Argument `noncurrent_days`

`noncurrent_version_expiration` wirkt nur auf ältere Versionen eines Objekts — die jeweils aktuelle Version bleibt unberührt. Das Argument `noncurrent_days` legt fest, nach wie vielen Tagen alte Versionen automatisch gelöscht werden.

</details>

**Terraform-Dokumentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration

---

### Schritt 1.2 – Storage deployen und testen

**Ziel:** Das Storage-Modul in `envs/dev/main.tf` einbinden (TODO A) und deployen.

Öffnet `envs/dev/main.tf` — dort findet ihr den auskommentierten TODO-A-Block. Kommentiert ihn ein und schaut, welche Argumente übergeben werden. Schaut auch in `modules/storage/outputs.tf`: welche Werte gibt das Modul zurück? Diese werden später von `processor` und `api` benötigt.

<details>
<summary>Hinweis – Modul aufrufen</summary>

Ein `module` Block in Terraform funktioniert wie ein Funktionsaufruf: `source` gibt den Pfad zum Modul an, die übrigen Argumente entsprechen den `variable`-Deklarationen in `modules/storage/variables.tf`. Schaut, welche Variablen das Modul erwartet — und welche Werte aus dem aufrufenden Kontext (`var.*`, `local.*`, `resource.*`) ihr übergeben könnt.

Nach dem Einkommentieren: `terraform init` ist nicht nötig, da das Modul bereits bekannt ist. Direkt mit `terraform validate` starten.

</details>

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

### Schritt 1.3 – Datenbank-Modul implementieren

**Ziel:** Implementiert `modules/database/main.tf`. Das Modul soll eine PostgreSQL-Datenbank auf RDS anlegen — mit Subnet Group, Security Group (als data source) und der RDS-Instanz selbst.

> **Hinweis:** Die Security Group `devk-dev-rds` (Port 5432) wurde vorab vom Admin angelegt. Ihr referenziert sie per `data`-Block, statt sie selbst zu erstellen — das ist ein wichtiges Terraform-Konzept: bestehende Infrastruktur einbinden, ohne sie zu verwalten.

**Anforderungen:**

| # | Was | Ressource |
|---|-----|-----------|
| 1 | DB Subnet Group aus den Default-Subnets | `aws_db_subnet_group` |
| 2 | Bestehende Security Group referenzieren | `data "aws_security_group"` |
| 3 | PostgreSQL RDS-Instanz (db.t3.micro, 20 GB) | `aws_db_instance` |

**Wo anfangen:**

1. Öffnet `modules/database/variables.tf` — welche Variablen stehen zur Verfügung?
2. Öffnet `modules/database/outputs.tf` — was soll das Modul zurückgeben?
3. Implementiert die drei Ressourcen der Reihe nach

```bash
terraform validate
terraform plan -target=module.database
```

<details>
<summary>Hinweis – Ressource 1: DB Subnet Group</summary>

`aws_db_subnet_group` braucht einen `name` und `subnet_ids`. RDS benötigt eine Subnet Group, damit AWS weiß, in welchen Availability Zones die Datenbank erreichbar sein soll — mindestens zwei AZs sind Pflicht.

Baut den Namen aus `var.project` und `var.environment`. Die Subnet-IDs kommen aus `var.subnet_ids`.

</details>

<details>
<summary>Hinweis – Ressource 2: Security Group als data source</summary>

Mit `data "aws_security_group"` referenziert ihr eine bereits existierende Security Group, ohne sie selbst zu verwalten. Das ist der Unterschied zu `resource`: Terraform erstellt nichts, sondern liest nur die ID aus.

Der Block braucht `name` und `vpc_id` zum Auffinden der SG. Den Namen könnt ihr aus `var.project` und `var.environment` zusammensetzen (Muster: `devk-dev-rds`). Die VPC-ID kommt aus `var.vpc_id`.

Referenziert die ID dann so: `data.aws_security_group.rds.id`

</details>

<details>
<summary>Hinweis – Ressource 3: RDS-Instanz</summary>

`aws_db_instance` hat viele Argumente — für den Workshop sind diese wichtig:
- `identifier` — eindeutiger Name der Instanz
- `engine = "postgres"`, `engine_version = "16.6"`
- `instance_class = "db.t3.micro"`, `allocated_storage = 20`
- `storage_encrypted = true`
- `db_name`, `username`, `password` — aus den Variablen
- `db_subnet_group_name` — Name der Subnet Group (Ressourcenreferenz)
- `vpc_security_group_ids` — Liste mit der SG-ID aus dem data-Block
- `publicly_accessible = true` — Workshop-Vereinfachung
- `skip_final_snapshot = true`, `backup_retention_period = 0`, `deletion_protection = false` — nur für Workshop

</details>

---

### Schritt 1.4 – Datenbank deployen

**Ziel:** Das Datenbank-Modul in `envs/dev/main.tf` einbinden (TODO B) und deployen.

> **Hinweis:** Folgende Ressourcen wurden vorab vom Admin angelegt — Terraform sucht sie per Name, ihr müsst nichts erstellen:
> - Security Group `devk-dev-rds` (Port 5432, für RDS)
> - IAM-Rolle `devk-dev-processor-role` (für die Processor-Lambda)
> - IAM-Rolle `devk-dev-api-role` (für die API-Lambda)

```bash
terraform apply -target=module.database
```

Das dauert ca. 8–10 Minuten. Nutzt die Zeit für die Diskussionspunkte unten.

**Überprüfen:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier devk-dev-claims \
  --query "DBInstances[0].DBInstanceStatus" \
  --output text \
  --region eu-central-1
```

Erwartete Ausgabe: `available`

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
2. `aws_lambda_function` – Python-Funktion, event-getriggert
3. `aws_lambda_permission` + `aws_s3_bucket_notification` – S3-Trigger (TODO: implementiert ihr selbst)

Schaut auch in `lambda-src/processor/handler.py` – was macht der Code konkret?

---

### Schritt 2.2 – S3-Trigger implementieren und deployen

**Ziel:** Den S3-Trigger selbst implementieren — zwei Ressourcen, die zusammen den Event-Flow herstellen — und die Processor-Lambda deployen.

Öffnet `modules/processor/main.tf` und implementiert den TODO-Block am Ende.

**Anforderungen:**

| # | Ressource | Was sie tut |
|---|-----------|-------------|
| 1 | `aws_lambda_permission` | Erlaubt S3, die Lambda aufzurufen |
| 2 | `aws_s3_bucket_notification` | Triggert die Lambda bei jedem Upload |

<details>
<summary>Hinweis – S3-Trigger: zwei Ressourcen, ein Konzept</summary>

AWS trennt Berechtigung und Konfiguration bewusst:

**`aws_lambda_permission`** ist eine IAM-ähnliche Erlaubnis auf Ebene der Lambda-Funktion selbst. Ohne sie würde S3 beim Aufruf ein `Access Denied` bekommen — auch wenn die Bucket-Notification korrekt konfiguriert ist. Relevante Argumente: `action`, `function_name`, `principal`, `source_arn`.

**`aws_s3_bucket_notification`** konfiguriert den Bucket so, dass er bei bestimmten Events aktiv wird. Der innere `lambda_function`-Block braucht `lambda_function_arn` und `events`. Für "jedes neue Objekt" lautet das Event `s3:ObjectCreated:*`.

Wichtig: `aws_s3_bucket_notification` muss ein `depends_on` auf `aws_lambda_permission` haben — sonst versucht Terraform die Notification zu setzen, bevor die Permission existiert.

</details>

```bash
terraform validate
terraform apply -target=module.processor
```

**Überprüfen:**

```bash
# Upload simuliert eine Schadensmeldung
echo "Schadensfoto Mock" > /tmp/schaden.jpg
aws s3 cp /tmp/schaden.jpg \
  s3://$(terraform output -raw s3_bucket)/policies/POL-12345/schaden.jpg

# Lambda-Logs live verfolgen (Strg+C zum Beenden)
aws logs tail $(terraform output -raw processor_log_group) --follow --region eu-central-1
```

Ihr solltet sehen: Lambda empfängt das S3-Event, legt die Tabelle an und schreibt einen Eintrag.

---

### Schritt 2.3 – API-Modul implementieren

**Ziel:** Das API-Modul selbst implementieren — Lambda-Funktion und API Gateway.

Öffnet `modules/api/main.tf`. Zwei TODO-Blöcke warten auf euch.

**Anforderungen:**

| # | Was | Ressource |
|---|-----|-----------|
| 1 | CloudWatch Log Group | `aws_cloudwatch_log_group` |
| 2 | Lambda-Funktion | `aws_lambda_function` |
| 3 | HTTP API | `aws_apigatewayv2_api` |
| 4 | Lambda-Integration | `aws_apigatewayv2_integration` |
| 5 | Drei Routen | `aws_apigatewayv2_route` (×3) |
| 6 | Permission für API Gateway | `aws_lambda_permission` |

Schaut auch in `lambda-src/api/handler.py` — wie werden Routen gematcht, wie wird die Presigned URL erzeugt?

<details>
<summary>Hinweis – TODO 1: Lambda-Funktion</summary>

Das Muster ist identisch zum Processor-Modul. Die Unterschiede:
- `function_name` endet auf `"claims-api"`
- `timeout = 15` (kürzer als Processor)
- Zusätzliche Env-Variable: `BUCKET_NAME = var.bucket_name`

Referenziert `local.role_arn` für die IAM-Rolle (bereits vorgegeben).

</details>

<details>
<summary>Hinweis – TODO 2: API Gateway</summary>

**`aws_apigatewayv2_api`**: Braucht `name`, `protocol_type = "HTTP"` und einen `cors_configuration`-Block (damit Browser-Requests funktionieren). Erlaubt Origins `["*"]`, Methods `["GET", "POST", "OPTIONS"]`, Headers `["Content-Type"]`.

**`aws_apigatewayv2_integration`**: Verbindet die API mit der Lambda. `integration_type = "AWS_PROXY"`, `integration_uri` ist die `invoke_arn` der Lambda-Funktion, `payload_format_version = "2.0"`.

**`aws_apigatewayv2_route`**: Jede Route braucht `api_id`, einen `route_key` (z.B. `"POST /claims"`) und `target` — das Format ist `"integrations/${aws_apigatewayv2_integration.lambda.id}"`. Legt drei Routen an: `POST /claims`, `GET /claims`, `GET /claims/{id}`.

**`aws_lambda_permission`**: Selbes Muster wie beim S3-Trigger, aber `principal = "apigateway.amazonaws.com"` und `source_arn = "${aws_apigatewayv2_api.claims.execution_arn}/*/*"`.

</details>

```bash
terraform validate
terraform plan -target=module.api
```

---

### Schritt 2.4 – API deployen

**Ziel:** Das gesamte Setup vervollständigen.

```bash
# Ohne -target – deployed jetzt alles
terraform apply
```

---

### Schritt 2.5 – End-to-End testen

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
aws logs tail $(terraform output -raw processor_log_group) --follow --region eu-central-1
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

# DEVK Terraform Workshop – Tag 2

Heute baut ihr das Backend eines Schadensmeldungs-Portals. Versicherungsnehmer können Schäden online melden, Dokumente hochladen und den Status abrufen.

Am Ende des Tages habt ihr:
- Ein Storage-Modul selbst in Terraform implementiert und in S3 deployed
- Eine PostgreSQL-Datenbank in Terraform implementiert und auf RDS deployed
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
| Provider, Variablen, Outputs | Alles davon – plus IAM, Lambda, RDS, API Gateway |

---

## AWS-Services heute

| Service | Was macht es? | Terraform-Ressource |
|---------|---------------|---------------------|
| **S3** | Objektspeicher, unbegrenzt skalierbar | `aws_s3_bucket` |
| **RDS** | Verwaltete relationale Datenbank | `aws_db_instance` |
| **Lambda** | Code ohne Server ausführen, event-getriggert | `aws_lambda_function` |
| **API Gateway** | HTTP-API-Endpunkte verwalten | `aws_apigatewayv2_api` |

---

## Setup

Arbeitet alle vier Schritte der Reihe nach durch. Wenn etwas nicht klappt, fragt bevor ihr weitermacht.

> **Wichtig:** Am Ende des Workshops `terraform destroy` ausführen – RDS läuft sonst weiter und verursacht Kosten.

---

### Schritt 1 – AWS-Zugangsdaten setzen

Umgebungsvariablen aus Tag 1 sind nach dem Schließen des Terminals weg. Setzt sie in jedem neuen Terminalfenster neu — euren Access Key habt ihr bereits aus Tag 1.

macOS / Linux:
```bash
export AWS_ACCESS_KEY_ID=EURE_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=EUER_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=eu-central-1
```

Windows (PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID = "EURE_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY = "EUER_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION = "eu-central-1"
```

> Wenn ihr später unerklärliche Authentifizierungsfehler bekommt: das ist meistens der erste Ort, den ihr prüfen solltet.

Falls ihr euren Access Key nicht mehr habt: AWS Console öffnen → rechts oben auf euren Benutzernamen → **Security credentials** → **Create access key**.

**Überprüfen:**

```bash
aws sts get-caller-identity
```

Der Befehl muss eine Account-ID zurückgeben. Eine Fehlermeldung bedeutet, die Zugangsdaten sind nicht korrekt gesetzt.

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

`terraform.tfvars` enthält eure persönlichen Eingabewerte für Terraform — darunter das Passwort für die RDS-Datenbank, die ihr in Part 1 anlegt.

Kopiert die Beispieldatei und erstellt daraus eure `terraform.tfvars`:

macOS / Linux:
```bash
cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

Windows (PowerShell):
```powershell
Copy-Item envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

Öffnet `envs/dev/terraform.tfvars` in eurem Editor und ersetzt `BitteHierEinStarkesPasswortSetzen!` durch ein eigenes Passwort. Die Datei ist in `.gitignore` — sie wird nie ins Repository eingecheckt.

> **Wichtig:** Sucht in `envs/dev/main.tf` und allen Modulen (`modules/storage/main.tf`,`modules/database/main.tf`, `modules/processor/main.tf`, `modules/api/main.tf`) nach dem Platzhalter `VORNAME` und ersetzt ihn durch euren Vornamen (z.B. `anna`). Das stellt sicher, dass eure Ressourcen eindeutige Namen bekommen und sich nicht mit denen anderer Teilnehmer überschneiden.

Installiert außerdem die Python-Abhängigkeiten für die Lambda-Funktionen:

```bash
pip3 install -r lambda-src/processor/requirements.txt -t lambda-src/processor/
pip3 install -r lambda-src/api/requirements.txt -t lambda-src/api/
```

**Überprüfen:** Der Platzhalter ist durch ein eigenes Passwort ersetzt, `VORNAME` ist durch euren Vornamen ersetzt, und die Abhängigkeiten wurden installiert.

---

### Schritt 4 – Terraform initialisieren

Wechselt in das Verzeichnis `envs/dev/` und lädt die Provider-Plugins herunter und registriert die Module:

```bash
cd terraform-ws-day-2/envs/dev
terraform init
```

Ihr solltet sehen: `Terraform has been successfully initialized!` Ihr seid jetzt bereit, mit den Aufgaben zu beginnen.

---

## Überblick: Was ist vorgegeben, was baut ihr selbst?

```
modules/
├── storage/     ← IHR implementiert main.tf       (Aufgabe Part 1)
├── database/    ← IHR implementiert main.tf       (Aufgabe Part 1)
├── processor/   ← vorgegeben, S3-Trigger als TODO (Aufgabe Part 2)
└── api/         ← IHR implementiert main.tf       (Aufgabe Part 2)

envs/dev/
├── main.tf      ← IHR füllt TODO A–D schrittweise aus
└── outputs.tf   ← Outputs werden schrittweise einkommentiert
```

**Euer Workflow für jeden Schritt:**

```
.tf-Datei schreiben  →  terraform plan  →  terraform apply
```

Führt `terraform plan` nach jeder neuen Ressource aus. So seht ihr Fehler früh und versteht, was Terraform vorhat.

---

## Part 1: Storage-Modul + Datenbank

### Schritt 1.1 – Storage-Modul implementieren

**Ziel:** Implementiert `modules/storage/main.tf`. Das Modul soll einen S3-Bucket mit Versionierung, serverseitiger Verschlüsselung und Public-Access-Block anlegen — so wie es die Anforderungen für ein Schadensmeldungs-Portal erfordern.

Gestern habt ihr bereits S3-Ressourcen gebaut. Heute geht es einen Schritt weiter: Versionierung, Verschlüsselung und Lifecycle.

**Anforderungen:**

| # | Was                                                           | Warum |
|---|---------------------------------------------------------------|-------|
| 1 | S3-Bucket mit Name `{project}-{environment}-claims-{VORNAME}` | Eindeutiger Name im globalen S3-Namespace |
| 2 | Versionierung aktivieren                                      | Dokumente dürfen nicht verloren gehen |
| 3 | Verschlüsselung mit AES256                                    | Daten at-rest verschlüsseln (DSGVO) |
| 4 | Public Access Block (alle 4 Flags = true)                     | Bucket darf nie öffentlich zugänglich sein |
| 5 | Lifecycle-Regel (Bonus)                                       | Alte Versionen nach 90 Tagen löschen |

**Wo anfangen:**

1. Öffnet `modules/storage/variables.tf` — was steht euch zur Verfügung?
2. Öffnet `modules/storage/outputs.tf` — was soll das Modul nach außen geben?
3. Implementiert `modules/storage/main.tf` Ressource für Ressource

```bash
# Nach jedem neu-initialisiertem Modul:
terraform init
# Nach jeder neuen Ressource testen:
terraform plan -target=module.storage
```

> Lösung bei Bedarf: `solutions/storage/main.tf`

<details>
<summary>Hinweis – Ressource 1: S3-Bucket</summary>

`aws_s3_bucket` braucht ein `bucket` Argument für den Namen. Bucket-Namen müssen global eindeutig sein — baut ihn aus den Variablen zusammen, die euch zur Verfügung stehen: `var.project` und `var.environment`. Terraform-Stringinterpolation funktioniert so: `"${var.project}-weiterer-text"`. Setzt außerdem `tags = var.tags`.

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

Alle vier sollen `true` sein. Das ist die sichere Konfiguration für einen Bucket, der nie öffentlich zugänglich sein soll — im Gegensatz zu Tag 1, wo ihr Public Access aufgemacht habt.

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

</details>

```bash
terraform init
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

**Ziel:** Implementiert `modules/database/main.tf`. Das Modul soll eine PostgreSQL-Datenbank auf RDS anlegen — mit Subnet Group, Security Group (beide als data source) und der RDS-Instanz selbst.

> **Hinweis:** Folgende Ressourcen wurden vorab vom Admin angelegt — ihr referenziert sie per `data`-Block, statt sie selbst zu erstellen. Das ist ein wichtiges Terraform-Konzept: bestehende Infrastruktur einbinden, ohne sie zu verwalten:
> - DB Subnet Group `devk-dev-claims` (überspannt alle Default-Subnets)
> - Security Group `devk-dev-rds` (Port 5432)

**Anforderungen:**

| # | Was | Ressource |
|---|-----|-----------|
| 1 | Bestehende DB Subnet Group referenzieren | `data "aws_db_subnet_group"` |
| 2 | Bestehende Security Group referenzieren | `data "aws_security_group"` |
| 3 | PostgreSQL RDS-Instanz (db.t3.micro, 20 GB) | `aws_db_instance` |

**Wo anfangen:**

1. Öffnet `modules/database/variables.tf` — welche Variablen stehen zur Verfügung?
2. Öffnet `modules/database/outputs.tf` — was soll das Modul zurückgeben?
3. Implementiert die drei Ressourcen der Reihe nach


<details>
<summary>Hinweis – Ressource 1: DB Subnet Group als data source</summary>

Mit `data "aws_db_subnet_group"` referenziert ihr eine bereits existierende Subnet Group — Terraform erstellt nichts, sondern liest nur den Namen aus. Das ist dasselbe Prinzip wie bei der Security Group.

Der Block braucht nur `name` zum Auffinden. Den Namen könnt ihr aus `var.project` und `var.environment` zusammensetzen (Muster: `{project}-{environment}-claims`).

Referenziert den Namen dann so: `data.aws_db_subnet_group.claims.name`

</details>

<details>
<summary>Hinweis – Ressource 2: Security Group als data source</summary>

Mit `data "aws_security_group"` referenziert ihr eine bereits existierende Security Group, ohne sie selbst zu verwalten. Das ist der Unterschied zu `resource`: Terraform erstellt nichts, sondern liest nur die ID aus.

Der Block braucht `name` und `vpc_id` zum Auffinden der SG. Den Namen könnt ihr aus `var.project` und `var.environment` zusammensetzen (Muster: `{project}-{environment}-rds`). Die VPC-ID kommt aus `var.vpc_id`.

Referenziert die ID dann so: `data.aws_security_group.rds.id`

</details>

<details>
<summary>Hinweis – Ressource 3: RDS-Instanz</summary>

`aws_db_instance` hat viele Argumente — für den Workshop sind diese wichtig:
- `identifier` — eindeutiger Name der Instanz (Muster: `{project}-{environment}-claims-VORNAME`)
- `engine = "postgres"`, `engine_version = "16.6"`
- `instance_class = "db.t3.micro"`, `allocated_storage = 20`
- `storage_encrypted = true`
- `db_name`, `username`, `password` — aus den Variablen
- `db_subnet_group_name` — Name der Subnet Group (data-Referenz)
- `vpc_security_group_ids` — Liste mit der SG-ID aus dem data-Block
- `publicly_accessible = true` — Workshop-Vereinfachung
- `skip_final_snapshot = true`, `backup_retention_period = 0`, `deletion_protection = false` — nur für Workshop

</details>

**Terraform-Dokumentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/db_subnet_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/security_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance


```bash
terraform plan -target=module.database
```
---

### Schritt 1.4 – Datenbank deployen

**Ziel:** Das Datenbank-Modul in `envs/dev/main.tf` und `envs/dev/outputs.tf` einbinden (TODO B) und deployen.

> **Hinweis:** Folgende Ressourcen wurden vorab vom Admin angelegt — Terraform sucht sie per Name, ihr müsst nichts erstellen:
> - DB Subnet Group `devk-dev-claims` (für RDS)
> - Security Group `devk-dev-rds` (Port 5432, für RDS)
> - IAM-Rolle `devk-dev-processor-role` (für die Processor-Lambda)
> - IAM-Rolle `devk-dev-api-role` (für die API-Lambda)

```bash
terraform init
terraform apply -target=module.database
```

Das dauert ca. 8–10 Minuten. Nutzt die Zeit für die Diskussionspunkte unten.

**Überprüfen:**

```bash
aws rds describe-db-instances \
  --db-instance-identifier devk-dev-claims-VORNAME \
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

Lest gemeinsam `modules/processor/main.tf`. Die Datei hat fünf Teile:

**1. `data "archive_file"`** — Source-Code zippen
Terraform zippt den Python-Code on-the-fly direkt aus dem Quellverzeichnis. `source_code_hash` sorgt dafür, dass Lambda bei jeder Code-Änderung automatisch neu deployed wird — ohne diesen Hash würde Terraform die Änderung nicht erkennen.

**2. `data "aws_iam_role"`** — IAM-Rolle nachschlagen
Die Rolle wurde vorab vom Admin angelegt (Teilnehmer haben keine `iam:CreateRole`-Berechtigung). Terraform liest sie hier per Name aus — ein typisches Muster, um bestehende Infrastruktur einzubinden ohne sie selbst zu verwalten.

**3. `aws_cloudwatch_log_group`** — Logs explizit verwalten
Lambda legt automatisch eine Log Group an — aber dann hat Terraform keine Kontrolle darüber. Durch explizite Verwaltung lässt sich die Retention auf 7 Tage setzen und die Log Group wird bei `terraform destroy` sauber gelöscht.

**4. `aws_lambda_function`** — die Funktion selbst
Verknüpft alle vorherigen Teile: gezippter Code, IAM-Rolle, Umgebungsvariablen für DB und S3. `depends_on` stellt sicher, dass die Log Group zuerst existiert, bevor Lambda deployed wird.

**5. TODO: `aws_lambda_permission` + `aws_s3_bucket_notification`** — S3-Trigger
Diese beiden Ressourcen sind noch nicht implementiert — das ist eure Aufgabe in Schritt 2.2.

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

**Terraform-Dokumentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification


Öffnet danach `envs/dev/main.tf` und `envs/dev/output.tf` und kommentiert den TODO-C-Block ein:

```hcl
module "processor" {
  source      = "../../modules/processor"
  project     = var.project
  environment = var.environment
  source_dir  = "${path.module}/../../lambda-src/processor"
  bucket_id   = module.storage.bucket_id
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}
```

```hcl
output "processor_log_group" {
  description = "CloudWatch Log Group der Processor-Lambda - zum Debuggen"
  value       = module.processor.log_group_name
}
```

```bash
terraform init
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

Die `cloudwatch_log_group` benötigt `name`, der exakt der Name der Lambda-Funktion sein muss, `retention_in_days = 7` und `tags`

Das Muster für die Lambda-Funktion ist analog zum Processor-Modul. Die Unterschiede:
- `function_name` endet auf `"claims-api"`
- `timeout = 15` (kürzer als Processor)
- Zusätzliche Env-Variable: `BUCKET_NAME = var.bucket_name`

Referenziert `data.aws_iam_role.api.arn` für die IAM-Rolle (bereits vorgegeben).

</details>

<details>
<summary>Hinweis – TODO 2: API Gateway</summary>

**`aws_apigatewayv2_api`**: Braucht `name`, `protocol_type = "HTTP"` und einen `cors_configuration`-Block (damit Browser-Requests funktionieren). Erlaubt Origins `["*"]`, Methods `["GET", "POST", "OPTIONS"]`, Headers `["Content-Type"]`.

**`aws_apigatewayv2_integration`**: Verbindet die API mit der Lambda. `integration_type = "AWS_PROXY"`,`api_id = aws_apigatewayv2_api.claims.id`, `integration_uri` ist die `invoke_arn` der Lambda-Funktion, `payload_format_version = "2.0"`.

**`aws_apigatewayv2_route`**: Jede Route braucht wieder die `api_id`, einen `route_key` (z.B. `"POST /claims"`) und `target` — das Format ist `"integrations/${aws_apigatewayv2_integration.lambda.id}"`. Legt drei Routen an: `POST /claims`, `GET /claims`, `GET /claims/{id}`.

**`aws_lambda_permission`**: Selbes Muster wie beim S3-Trigger, aber `principal = "apigateway.amazonaws.com"` und `source_arn = "${aws_apigatewayv2_api.claims.execution_arn}/*/*"`.

</details>

**Terraform-Dokumentation:**
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission


```bash
terraform plan -target=module.api
```

Wenn der Plan sauber ist: Modul einbinden und Outputs freischalten.

**`envs/dev/main.tf`** – TODO-D-Block auskommentieren:

```hcl
module "api" {
  source      = "../../modules/api"
  project     = var.project
  environment = var.environment
  source_dir  = "${path.module}/../../lambda-src/api"
  bucket_name = module.storage.bucket_name
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}
```

**`envs/dev/outputs.tf`** – beide API-Outputs auskommentieren:

```hcl
output "api_url" {
  description = "Base URL der Claims-API"
  value       = module.api.api_endpoint
}

output "api_log_group" {
  description = "CloudWatch Log Group der API-Lambda"
  value       = module.api.log_group_name
}
```

---

### Schritt 2.4 – API deployen

**Ziel:** Das gesamte Setup vervollständigen.

```bash
terraform init
# Ohne -target – deployed jetzt alles
terraform apply
```

Die API-URL ausgeben:

```bash
terraform output -raw api_url
```

Falls du an irgendeinem Punkt in die API-Logs schauen willst, machst du das mit
```bash
aws logs tail $(terraform output -raw api_log_group) --follow --region eu-central-1
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
```

```bash
# Einzelnen Claim abrufen (ID aus der POST-Antwort einsetzen)
curl -s ${API_URL}/claims/CLM-XXXXXXXXXX | jq
```

**Presigned URL – der Browser-Upload-Flow:**

Im POST-Response ist eine `upload_url`. Das ist eine AWS Presigned URL – sie erlaubt einem Browser für eine Stunde, direkt nach S3 zu uploaden, ohne eigene AWS-Credentials zu haben. Schaut in `lambda-src/api/handler.py` nach, wie sie erzeugt wird.

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

Der S3 Bucket muss leer sein, um ihn löschen zu können.
Geht dafür bitte in die [AWS-Konsole](https://856021348966.signin.aws.amazon.com/console), entweder in "Kürzlich besucht" oder in "Alle Services ansehen" in "S3", wählt euren Bucket aus (devk-dev-claims-VORNAME) und klickt auf "Leer" und bestätigt dies. Anschließend könnt ihr mit `terraform destroy` alle Elemente aufräumen.

```bash
# S3-Bucket muss leer sein, sonst schlägt destroy fehl
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

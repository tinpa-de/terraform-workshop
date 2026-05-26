# Troubleshooting

## Terraform-Probleme

### „Error acquiring the state lock"
Jemand anders (oder ein abgebrochener Run) hält den Lock.
```bash
# Lock-ID aus der Fehlermeldung kopieren
terraform force-unlock <LOCK_ID>
```
**Wann nicht:** Wenn wirklich noch jemand parallel arbeitet.

### „BucketAlreadyExists" beim S3-Bucket
S3-Bucket-Namen sind global eindeutig. Wir nutzen `random_id` als Suffix.
Wenn es trotzdem auftritt: `terraform apply` nochmal – `random_id` generiert
neuen Wert.

### „InvalidParameterValue: ... cannot be used with restored snapshot"
Beim ersten `apply` der RDS – Terraform tut zu schnell, bevor Subnet Group
fertig ist. Einfach `terraform apply` wiederholen.

### „Error: timeout while waiting for state"
RDS-Erstellung dauert >10 Min. Geduld. Wenn es nach 20 Min hängt: in der
AWS-Console nachschauen, ob die Instanz im Status „failed" ist.

### `archive_file` baut leeres ZIP
- Pfad in `source_dir` prüfen
- Keine versteckten Files (z.B. `.pyc`) in dem Ordner?
- Manuell prüfen: `terraform console` → `data.archive_file.lambda`

### „Provider produced inconsistent result after apply"
Meist Race Condition oder ein Provider-Bug. Erste Hilfe:
```bash
terraform refresh
terraform apply
```

---

## Lambda-Probleme

### Lambda läuft, aber nichts passiert in der DB

**1. Logs prüfen:**
```bash
aws logs tail $(terraform output -raw processor_log_group) --follow
```

**2. „Connection timed out" auf RDS?**
→ Security Group Ingress fehlt. In RDS-SG muss Lambda-SG als Source erlaubt sein.
```bash
aws ec2 describe-security-groups \
  --group-ids $(terraform state show module.database.aws_security_group.rds | grep '^id' | awk '{print $3}' | tr -d '"')
```

**3. „role cannot be assumed"**
→ IAM-Rolle braucht Trust Relationship für `lambda.amazonaws.com`. Sollte
durch Modul gesetzt sein – sonst `aws_iam_role.assume_role_policy` prüfen.

**4. „No module named psycopg2"**
→ Lambda Layer fehlt oder falsche Architektur/Runtime-Version. Im env-Setup
gibt es die Klayers-ARN; prüfen, ob `python3.12` zur Lambda passt.

### S3-Trigger feuert nicht

**1. Permission set?**
```bash
aws lambda get-policy --function-name $(terraform output -raw processor_function_name 2>/dev/null \
  || echo "devk-dev-claims-processor")
```
Es muss eine Statement mit `Principal: s3.amazonaws.com` geben.

**2. Notification konfiguriert?**
```bash
aws s3api get-bucket-notification-configuration \
  --bucket $(terraform output -raw s3_bucket)
```

**3. Lädst du an der richtigen Stelle hoch?**
Notification filtert standardmäßig nicht – jedes ObjectCreated triggert.

---

## RDS-Probleme

### „password authentication failed"
- Hat sich das `db_password` zwischendrin geändert? `terraform state show
  module.database.aws_db_instance.claims` zeigt das aktuell gespeicherte.
- Sonderzeichen im Passwort? AWS akzeptiert die meisten, aber `/`, `"`, `@`
  und Leerzeichen sind problematisch.

### „could not translate host name to address"
Lambda läuft nicht in der VPC, in der RDS ist. `vpc_config` der Lambda
prüfen.

### `terraform destroy` schlägt fehl: „DBInstance not in available state"
RDS wird gerade verändert (z.B. Snapshot vor dem Löschen).
- `skip_final_snapshot = true` setzen (im Workshop-Code schon der Fall)
- Warten und nochmal `destroy`

---

## API-Gateway-Probleme

### HTTP 500 von der API
```bash
aws logs tail $(terraform output -raw api_log_group) --follow
```
99% der Fälle: DB-Connection-Fehler. Siehe Lambda-Probleme oben.

### HTTP 404 für eine Route
Route in `modules/api/main.tf` definiert? `aws_apigatewayv2_route` muss
existieren UND der HTTP-Method-Match muss stimmen (case-sensitive bei der
Route, `POST /claims` ≠ `post /claims`).

### CORS-Fehler im Browser
`cors_configuration` im API-Modul – `allow_origins = ["*"]` ist für den
Workshop OK; in Produktion natürlich einschränken.

---

## Generelle AWS-Probleme

### „You are not authorized to perform: iam:CreateRole"
→ Eure AWS-Credentials haben nicht genug Rechte. Im Workshop-Account sollten
PowerUser-ähnliche Rechte ausreichen.

### „Rate exceeded"
AWS-API-Throttling. Einfach nochmal versuchen, ggf. `-parallelism=5`:
```bash
terraform apply -parallelism=5
```

### Region-Verwirrung
Alle Ressourcen sollen in `eu-central-1` sein. Falls ihr was in `us-east-1`
seht: `AWS_REGION` und `AWS_DEFAULT_REGION` Umgebungsvariablen checken,
und `provider "aws" { region = ... }`.

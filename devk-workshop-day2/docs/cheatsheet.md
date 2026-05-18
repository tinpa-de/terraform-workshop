# Terraform Cheatsheet

## Die wichtigsten Kommandos

### Initialisierung
```bash
terraform init              # Provider + Module herunterladen
terraform init -upgrade     # Provider auf neueste passende Version updaten
terraform init -reconfigure # Backend neu konfigurieren
```

### Planung & Anwendung
```bash
terraform plan                          # Zeigt, was geändert wird
terraform plan -out=tfplan              # Plan speichern
terraform apply                         # Änderungen anwenden (mit Bestätigung)
terraform apply tfplan                  # Gespeicherten Plan anwenden
terraform apply -auto-approve           # Ohne Nachfrage (Vorsicht!)
terraform apply -target=module.storage  # Nur ein Modul anwenden
terraform apply -var="region=eu-west-1" # Variable überschreiben
```

### Zerstören
```bash
terraform destroy                          # Alles löschen
terraform destroy -target=module.processor # Nur ein Modul löschen
```

### State
```bash
terraform state list                       # Alle Ressourcen im State
terraform state show aws_s3_bucket.claims  # Details einer Ressource
terraform state rm aws_s3_bucket.claims    # Aus State entfernen (NICHT löschen!)
terraform state mv old.name new.name       # Umbenennen im State
terraform state pull > state.json          # State exportieren
terraform refresh                          # State mit echter Welt syncen
```

### Outputs & Variablen
```bash
terraform output                  # Alle Outputs anzeigen
terraform output api_url          # Einzelnen Output
terraform output -raw api_url     # Ohne Anführungszeichen (für $())
terraform output -json            # Maschinenlesbar
```

### Format & Validation
```bash
terraform fmt              # Code formatieren (current dir)
terraform fmt -recursive   # Alle Unterordner
terraform validate         # Syntax & Konfiguration prüfen
terraform console          # Interaktive REPL für Ausdrücke
```

### Import (Bestehende Ressourcen übernehmen)
```bash
terraform import aws_s3_bucket.claims my-existing-bucket-name
```

### Workspace (wenn ihr mit mehreren Umgebungen arbeitet)
```bash
terraform workspace list
terraform workspace new staging
terraform workspace select dev
```

---

## Nützliche Patterns

### Nur einen Plan generieren, ohne Provider-API-Calls (offline)
```bash
terraform plan -refresh=false
```

### Provider-Lock-File aktualisieren (für CI)
```bash
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

### Bestimmte Ressource neu erstellen
```bash
terraform apply -replace=aws_lambda_function.processor
```

(Früher hieß das `terraform taint` – ist deprecated.)

### Sensible Outputs anzeigen
```bash
terraform output -raw rds_endpoint
```

---

## Umgebungsvariablen

| Variable | Wirkung |
|---|---|
| `TF_VAR_db_password` | Setzt `var.db_password` |
| `TF_LOG=DEBUG` | Aktiviert Debug-Logging |
| `TF_LOG_PATH=tf.log` | Schreibt Logs in Datei |
| `AWS_PROFILE` | AWS-Credentials-Profil |
| `AWS_REGION` | AWS Region |

```bash
export TF_VAR_db_password="$(openssl rand -base64 24)"
TF_LOG=DEBUG terraform plan 2> debug.log
```

---

## Häufig genutzte AWS-CLI-Kommandos

### S3
```bash
aws s3 ls                                    # Buckets auflisten
aws s3 ls s3://my-bucket/                    # Inhalt anzeigen
aws s3 cp local.txt s3://my-bucket/file.txt  # Upload
aws s3 rm s3://my-bucket/file.txt            # Löschen
aws s3 rm s3://my-bucket --recursive         # Bucket leeren
```

### Lambda
```bash
aws lambda invoke --function-name my-fn out.json    # Manuell aufrufen
aws lambda get-function --function-name my-fn       # Config anzeigen
aws logs tail /aws/lambda/my-fn --follow            # Logs streamen
aws logs tail /aws/lambda/my-fn --since 5m          # Letzte 5 Min
```

### RDS
```bash
aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
aws rds describe-db-instances --db-instance-identifier devk-dev-claims
```

### API Gateway
```bash
aws apigatewayv2 get-apis
curl -v https://xxx.execute-api.eu-central-1.amazonaws.com/claims
```

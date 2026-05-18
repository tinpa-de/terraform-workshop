# Best Practices – was wir im Workshop bewusst NICHT gemacht haben

Dieser Slot um 15:00 fasst zusammen, an welchen Stellen unser Workshop-Setup
nicht produktionsreif ist und wie man es besser machen würde. Eigentlich
ein guter Auftakt zur Diskussion.

## 1. Secrets

**Workshop:**
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```
Passwort steht in `terraform.tfvars` (oder Env-Var).

**Besser:**
- AWS Secrets Manager: Terraform legt das Secret an, RDS bezieht das Passwort daraus, Lambda holt es zur Laufzeit.
- Für RDS gibt es `manage_master_user_password = true` – AWS verwaltet das Passwort komplett selbst.
- In CI/CD: niemals Secrets in tfvars-Files; stattdessen Vault, AWS SSM Parameter Store, oder Workload Identity.

## 2. State Management

**Workshop:**
- Lokaler State auf eigener Maschine (oder erst am Ende S3 Backend).

**Besser:**
- Remote Backend mit S3 + DynamoDB-Lock (oder Terraform Cloud / Spacelift / Atlantis).
- State-Bucket mit Versioning + Encryption.
- Pro Umgebung eigener State (`envs/dev`, `envs/prod`).
- State enthält Secrets im Klartext – Zugriff strikt einschränken.

## 3. Datenbank-Resilienz

**Workshop:**
```hcl
skip_final_snapshot     = true
backup_retention_period = 0
deletion_protection     = false
```

**Besser:**
- `skip_final_snapshot = false` und `final_snapshot_identifier` setzen
- `backup_retention_period >= 7` (gesetzlich oft >= 30 für Versicherungen!)
- `deletion_protection = true`
- `multi_az = true` für Failover
- Read Replicas für Reporting-Last

## 4. Networking

**Workshop:**
- Default VPC mit public Subnets
- Lambdas in public Subnets

**Besser:**
- Eigene VPC mit private + public Subnets
- RDS und Lambda in private Subnets
- NAT Gateway (oder VPC Endpoints) für Internet-Zugriff von Lambdas
- VPC Endpoints für S3, Secrets Manager – kostengünstiger und sicherer

## 5. IAM

**Workshop:**
- AWS-Managed Policies wo möglich (z.B. `AWSLambdaVPCAccessExecutionRole`)

**Besser:**
- Least Privilege: nur die exakt benötigten Actions
- Statt `s3:GetObject` auf `bucket/*` → nur auf das Prefix, das die Lambda braucht
- Boundary Policies, um versehentliche Eskalation zu verhindern
- AWS Access Analyzer regelmäßig laufen lassen

## 6. Lambda Deployment

**Workshop:**
```hcl
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/processor.zip"
}
```
Terraform packt den Code beim Apply.

**Besser:**
- Lambda-Code in eigener Pipeline bauen (Tests, Linting, Layer-Caching)
- Artifact in S3 ablegen, Terraform referenziert nur `s3_bucket`/`s3_key`
- Versioning + Aliasing für Blue/Green Deployments
- Lambda als Container Image für komplexere Dependencies

## 7. Beobachtbarkeit

**Workshop:**
- CloudWatch Logs mit 7 Tagen Retention

**Besser:**
- Strukturierte Logs (JSON)
- Metriken via CloudWatch Embedded Metric Format oder OpenTelemetry
- Alarms auf Errors, Throttles, DB-Connections
- X-Ray Tracing für Request-Latenz
- Dashboards (auch via Terraform!)

## 8. Module

**Workshop:**
- Eigene Module für jede Komponente, lokal eingebunden.

**Besser:**
- Module versionieren (Git Tags) und über `?ref=v1.2.3` einbinden
- Wo möglich: Terraform Registry Module nutzen (`terraform-aws-modules/vpc/aws` usw.)
- Eigene Module dokumentieren mit `terraform-docs`
- Module testen (Terratest, OpenTofu Test Framework)

## 9. Code-Qualität & CI/CD

- `terraform fmt` als Pre-Commit-Hook
- `terraform validate` in CI
- [tflint](https://github.com/terraform-linters/tflint) für statische Analyse
- [tfsec](https://github.com/aquasecurity/tfsec) / [Checkov](https://www.checkov.io/) für Security-Scans
- `terraform plan` in jeder PR posten (Atlantis, Spacelift, GitHub Actions)
- Apply nur aus dem `main`-Branch nach Merge

## 10. API & Auth

**Workshop:**
- API öffentlich erreichbar, keine Auth.

**Besser:**
- Cognito User Pool oder IAM Auth für Endkunden-API
- API Keys + Usage Plans für interne Aufrufer
- WAF davor (Rate Limiting, Bot Protection)
- Custom Domain mit ACM-Zertifikat

---

## Ein Gedanke zum Mitnehmen

> Terraform ist nicht "das richtige Setup" – Terraform ist "das Setup, das ihr
> heute habt, reproduzierbar und im Code". Die Best Practices oben sind nicht
> alle von Anfang an nötig. Aber sie sind die nächsten Schritte, sobald
> "es läuft auf Dev" zu "es muss auch nachts um 3 wieder laufen" wird.

# Terraform Workshop

Willkommen zu diesem Terraform-Workshop!

Am Ende wirst du:
- Eine öffentliche statische Website auf AWS mit Terraform bereitgestellt haben
- Das Setup in ein wiederverwendbares Modul extrahiert haben
- Zwei weitere Websites mit diesem Modul und nur wenigen Zeilen neuem Code bereitgestellt haben

---

## Hintergrund: Was ist Terraform?

Terraform ist ein **Infrastructure as Code (IaC)**-Werkzeug. Anstatt durch die AWS Management Console zu klicken, um einen Server, einen Speicher-Bucket oder eine Netzwerkregel zu erstellen, beschreibst du in einfachen Textdateien (`.tf`-Dateien), was du möchtest. Terraform ermittelt dann, was erstellt, geändert oder gelöscht werden muss, damit die reale Infrastruktur deiner Beschreibung entspricht.

Hier sind die Kernkonzepte, denen du in diesem Workshop begegnen wirst:

| Begriff | Bedeutung |
|---------|-----------|
| **Resource** | Ein einzelnes Infrastrukturelement — ein S3-Bucket, eine Datenbanktabelle, ein DNS-Eintrag. Ressourcen werden in `.tf`-Dateien deklariert. |
| **Provider** | Ein Plugin, das Terraform nutzt, um mit einer bestimmten Plattform zu kommunizieren. Der `aws`-Provider weiß zum Beispiel, wie AWS-Ressourcen erstellt und verwaltet werden. |
| **State** | Terraform speichert alle erstellten Ressourcen in einer *State-Datei*. Damit weiß es, was bereits existiert und was noch geändert werden muss. |
| **Plan** | Ein Probelauf: `terraform plan` zeigt genau, was Terraform *tun würde*, ohne etwas zu ändern. **Immer vor dem Apply ausführen.** |
| **Apply** | `terraform apply` führt die im Plan gezeigten Änderungen aus. Terraform fragt immer nach einer Bestätigung, bevor echte Änderungen vorgenommen werden. |
| **Variable** | Eine benannte Eingabe, die deine Konfiguration wiederverwendbar und flexibel macht — wie ein Parameter in einer Funktion. |
| **Module** | Eine wiederverwendbare Gruppe von Ressourcen, verpackt in einem eigenen Ordner. Wie eine Funktion, die du mehrfach mit unterschiedlichen Argumenten aufrufen kannst. Du arbeitest in Aufgabe 2 mit Modulen. |

---

## Was wir bauen

**Aufgabe 1 — Statische Website:** Du richtest einen S3-Bucket ein, lädst eine HTML-Datei hoch, konfigurierst öffentlichen Zugriff und aktivierst das statische Website-Hosting von S3 — Schritt für Schritt.

**Aufgabe 2 — Module:** Du extrahierst das Setup aus Aufgabe 1 in ein wiederverwendbares Terraform-Modul und stellst dann zwei weitere Websites bereit, indem du das Modul zweimal aufrufst.

---

## Repository-Struktur

```
terraform-workshop/
└── terraform-ws-day-1/
    ├── resources/
    │   ├── static-page/index.html       ← Website-Datei für Aufgabe 1
    │   ├── static-page-2/index.html     ← Website-Datei für Aufgabe 2 (zweite Seite)
    │   └── static-page-3/index.html     ← Website-Datei für Aufgabe 2 (dritte Seite)
    └── terraform/
        ├── initialize-lock-db/          ← Einmalige Einrichtung: erstellt deine persönliche State-Lock-Tabelle
        │   ├── main.tf
        │   ├── variables.tf
        │   └── default.auto.tfvars      ← Du bearbeitest diese Datei in Setup-Schritt 4
        ├── main.tf                      ← Du bearbeitest diese Datei in Setup-Schritt 5
        └── variables.tf
```

In Aufgabe 1 fügst du neue `.tf`-Dateien in `terraform/` hinzu. In Aufgabe 2 erstellst du den Ordner `terraform/modules/`.

---

## Setup

Arbeite alle fünf Schritte der Reihe nach durch, bevor du mit den Aufgaben beginnst. Wenn etwas fehlschlägt, bitte um Hilfe, bevor du weitermachst.

---

### Schritt 1 – Erforderliche Tools installieren

Du benötigst zwei Tools auf deinem Rechner: **Terraform** (zur Verwaltung der Infrastruktur) und die **AWS CLI** (zur Authentifizierung bei AWS).

#### macOS

Öffne ein Terminal und führe aus:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform awscli
```

> Wenn du Homebrew noch nicht installiert hast, folge zuerst den Anweisungen unter https://brew.sh.

#### Windows

Öffne **PowerShell als Administrator** und führe aus:

```powershell
winget install HashiCorp.Terraform
winget install Amazon.AWSCLI
```

> Schließe PowerShell nach der Installation und öffne es erneut, damit die neuen Befehle in deinem PATH verfügbar sind.

**Überprüfe, ob beide Tools korrekt installiert sind:**

```bash
terraform version
aws --version
```

Beide Befehle sollten eine Versionsnummer ausgeben. Wenn ein Befehl nicht gefunden wird, überprüfe die Installationsschritte erneut.

---

### Schritt 2 – Den `tf`-Alias einrichten

Im gesamten Workshop tippen wir `tf` statt `terraform`, um Zeit zu sparen. Dieser Schritt richtet einen Shell-Alias ein, der `tf` zu einem Äquivalent von `terraform` macht.

#### macOS / Linux (zsh)

```bash
echo 'alias tf=terraform' >> ~/.zshrc && source ~/.zshrc
```

#### Windows (PowerShell)

```powershell
if (!(Test-Path $PROFILE)) { New-Item -Path $PROFILE -Force }
Add-Content $PROFILE 'Set-Alias tf terraform'
. $PROFILE
```

**Überprüfe, ob der Alias funktioniert:**

```bash
tf version
```

---

### Schritt 3 – Bei AWS anmelden und Zugangsdaten konfigurieren

Dieser Workshop läuft auf einem gemeinsamen AWS-Konto. Du authentifizierst dich mit einem **IAM-Benutzer** und einem Zugriffsschlüssel.

**Melde dich bei der AWS Console an:**

Öffne https://console.aws.amazon.com in deinem Browser und melde dich mit dem IAM-Benutzernamen und Passwort an, die du erhalten hast.

**Erstelle einen Zugriffsschlüssel:**

1. Klicke rechts oben auf deinen Benutzernamen → **Security credentials**.
2. Scrolle nach unten zu **Access keys** und klicke auf **Create access key**.
3. Wähle **Command Line Interface (CLI)** als Anwendungsfall, bestätige die Empfehlung und klicke auf **Next**.
4. Klicke auf **Create access key**.
5. **Kopiere jetzt sowohl die Access Key ID als auch den Secret Access Key** — das Secret wird nur einmal angezeigt.

**Speichere die Zugangsdaten als Umgebungsvariablen:**

macOS / Linux:
```bash
export AWS_ACCESS_KEY_ID=DEINE_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=DEIN_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=eu-west-1
```

Windows (PowerShell):
```powershell
$env:AWS_ACCESS_KEY_ID = "DEINE_ACCESS_KEY_ID"
$env:AWS_SECRET_ACCESS_KEY = "DEIN_SECRET_ACCESS_KEY"
$env:AWS_DEFAULT_REGION = "eu-west-1"
```

> Diese Variablen gelten nur für die aktuelle Terminal-Sitzung. Du musst sie jedes Mal neu setzen, wenn du ein neues Terminal-Fenster öffnest. Wenn du später Authentifizierungsfehler erhältst, ist das die erste Stelle, die du überprüfen solltest.

**Überprüfe deinen Zugang:**

```bash
aws s3 ls
```

Du solltest eine Liste von S3-Buckets sehen. Bei einem Authentifizierungsfehler überprüfe, ob alle drei Umgebungsvariablen korrekt gesetzt sind.

---

## Aufgabe 1 – Eine statische Website auf S3 hosten

In dieser Aufgabe erstellst du einen S3-Bucket und konfigurierst ihn so, dass er eine öffentliche statische Website bereitstellt. Alle Terraform-Dateien, die du erstellst, kommen in das Verzeichnis `terraform/`.

### Ressourcendeklarationen verstehen

Jede Ressource in Terraform folgt demselben Muster:

```hcl
resource "TYP" "LOKALER_NAME" {
  argument = "wert"
}
```

- `TYP` ist der vom Provider definierte Ressourcentyp, zum Beispiel `aws_s3_bucket`.
- `LOKALER_NAME` ist ein von dir gewählter Name — er wird nur innerhalb deines Terraform-Codes verwendet, um diese spezifische Ressource von anderer Stelle zu referenzieren.
- Die Argumente im Block konfigurieren die Ressource. Welche Argumente existieren und welche erforderlich sind, ist in der [Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) dokumentiert.

**Eine andere Ressource referenzieren** ermöglicht es dir, deren Attribute zu verwenden, ohne Werte manuell zu kopieren. Zum Beispiel:

```hcl
bucket_id = aws_s3_bucket.my_bucket.id
```

Dies liest das `id`-Attribut der Ressource vom Typ `aws_s3_bucket` mit dem Namen `my_bucket`. Terraform ermittelt automatisch die richtige Reihenfolge, in der die beiden Ressourcen erstellt werden.

**Dein Arbeitsablauf für jeden Schritt:**

```
.tf-Dateien schreiben oder ändern  →  tf plan  →  Ausgabe prüfen  →  tf apply
```

Überspringe niemals `tf plan`. Es zeigt genau, was passieren wird, bevor etwas in AWS geändert wird.

### Über Provider in diesem Workshop

Die Datei `terraform/main.tf` konfiguriert bereits zwei AWS-Provider für dich:

- `aws.frankfurt` — verwendet für die meisten Ressourcen (Region: `eu-central-1`)

Um einer Ressource einen bestimmten Provider zuzuweisen, füge dieses Argument in deren Block ein:

```hcl
provider = aws.frankfurt
```

Verwende `aws.frankfurt` für jede Ressource, die du in Aufgabe 1 erstellst.

---

### 1.1 – Einen S3-Bucket erstellen

**Ziel:** Erstelle eine neue Datei namens `terraform/s3.tf` und deklariere darin eine `aws_s3_bucket`-Ressource. Der Bucket-Name muss **global eindeutig über ganz AWS** sein — stelle ihm deinen Namen voran, zum Beispiel `justus-workshop-static-page`.

Führe `tf plan` aus und lies die Ausgabe, um zu verstehen, was Terraform tun wird, dann führe `tf apply` aus.

**Überprüfung:** Öffne nach dem Apply die AWS Console und navigiere zu S3 — dein Bucket sollte in der Liste erscheinen. Alternativ kannst du `aws s3 ls` in deinem Terminal ausführen.

**Terraform-Dokumentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket

<details>
<summary>Hinweis</summary>

Die `aws_s3_bucket`-Ressource benötigt in diesem Stadium nur ein `bucket`-Argument (den Namen) und das `provider`-Argument. Halte es minimal — du wirst das Verhalten des Buckets in den folgenden Schritten über separate, dedizierte Ressourcen konfigurieren. Das ist der Terraform-Ansatz: eine Ressource, ein Thema.

S3-Bucket-Namen müssen global eindeutig über alle AWS-Konten weltweit sein. Deinen Namen, das Unternehmen und das heutige Datum einzubeziehen (z.B. `justus-nl-20250517`) ist eine zuverlässige Methode, um Konflikte mit Buckets anderer Personen zu vermeiden.

</details>

---

### 1.2 – Die Website-Datei hochladen

**Ziel:** Füge eine `aws_s3_object`-Ressource zu `terraform/s3.tf` hinzu, die `../resources/static-page/index.html` in deinen Bucket hochlädt. Verwende eine **Referenz** auf deine Bucket-Ressource statt den Bucket-Namen als String zu kopieren. Setze den korrekten Content-Type, damit Browser wissen, dass sie die Datei als Webseite rendern sollen.

Führe `tf plan` → `tf apply` aus, dann überprüfe, ob die Datei in deinem Bucket im Tab **Objects** in der AWS Console erscheint.

**Terraform-Dokumentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object

<details>
<summary>Hinweis</summary>

`aws_s3_object` benötigt drei Schlüsselargumente:

- `bucket` — der Name des Buckets, in den hochgeladen werden soll. Verwende eine Ressourcenreferenz statt eines hartcodierten Strings: `aws_s3_bucket.DEIN_LOKALER_NAME.id`
- `key` — der Name, den die Datei in S3 haben soll, z.B. `"index.html"`
- `source` — der lokale Dateipfad, relativ zum Verzeichnis `terraform/`

Der korrekte `content_type` für eine HTML-Datei ist `"text/html"`. Ohne diesen werden Browser die Datei herunterladen statt sie zu rendern.

Um sicherzustellen, dass Terraform bemerkt, wenn sich der Dateiinhalt ändert, und die Datei erneut hochlädt, setze `etag = filemd5("../resources/static-page/index.html")`. Terraform vergleicht diesen Hash bei jedem Plan und löst ein Update aus, wenn sich die Datei ändert.

</details>

---

### 1.3 – Öffentlichen Lesezugriff erlauben

Standardmäßig blockiert AWS den gesamten öffentlichen Zugriff auf jeden S3-Bucket. Um eine öffentliche Website zu hosten, musst du zwei separate Schritte durchführen:

1. **Die "Block Public Access"-Einstellungen** des Buckets deaktivieren.
2. **Eine Bucket-Policy anhängen**, die jedem anonymen Internetbesucher das Recht gewährt, Objekte zu lesen.

Beide erfordern ihre eigene Terraform-Ressource. Nach dem Apply sollte jeder Internetnutzer `index.html` abrufen können, ohne sich bei AWS zu authentifizieren.

**Ziel:** Füge beide Ressourcen zu `s3.tf` hinzu und wende sie an.

**Terraform-Dokumentation:**
- Public Access Block: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
- Bucket Policy: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy

<details>
<summary>Hinweis — Block Public Access deaktivieren</summary>

`aws_s3_bucket_public_access_block` hat vier boolesche Argumente — `block_public_acls`, `block_public_policy`, `ignore_public_acls` und `restrict_public_buckets` — die alle standardmäßig `true` (alles blockiert) sind. Setze alle vier auf `false`, um die Einschränkung vollständig aufzuheben.

Referenziere denselben Bucket, den du in Schritt 1.1 erstellt hast.

</details>

<details>
<summary>Hinweis — Bucket Policy</summary>

Eine Bucket-Policy ist ein JSON-Dokument, das definiert, wer was mit deinem Bucket tun kann. Die `aws_s3_bucket_policy`-Ressource nimmt ein `policy`-Argument entgegen, das dieses JSON als String enthält.

Die benötigte Policy gewährt Folgendes:
- **Principal:** `"*"` — alle, einschließlich nicht authentifizierter Benutzer
- **Action:** `"s3:GetObject"` — das Recht, Objekte herunterzuladen
- **Resource:** jedes Objekt in deinem Bucket — das ARN-Muster ist `"arn:aws:s3:::DEIN_BUCKET_NAME/*"`

Die Verwendung der eingebauten `jsonencode()`-Funktion von Terraform ermöglicht es dir, das JSON als native HCL-Map zu schreiben, was Probleme mit Anführungszeichen vermeidet und leichter zu lesen ist.

**Wichtige Reihenfolge:** AWS lehnt die Bucket-Policy ab, solange "Block Public Access" noch aktiviert ist. Terraform ist sich dieser AWS-spezifischen Abhängigkeit nicht automatisch bewusst — du musst sie explizit angeben, indem du `depends_on = [aws_s3_bucket_public_access_block.DEIN_LOKALER_NAME]` zur Bucket-Policy-Ressource hinzufügst. Dies stellt sicher, dass die Block-Public-Access-Einstellungen angewendet werden, bevor die Policy gesetzt wird.

</details>

**Überprüfung:** Öffne ein privates / Inkognito-Browserfenster. Navigiere in der AWS Console zu deinem Bucket, klicke auf `index.html` und kopiere die **Object URL** (sichtbar im Bereich Properties oder Details). Füge diese URL in das private Browserfenster ein. Du solltest auf die Datei zugreifen können, ohne bei AWS angemeldet zu sein. Wenn du einen "Access Denied"-Fehler siehst, überprüfe beide Ressourcen aus diesem Schritt erneut.

---

### 1.4 – Statisches Website-Hosting aktivieren

Wenn ein Browser ein Objekt über eine reguläre S3-URL anfordert, gibt S3 die Datei als einfachen Download zurück. Das statische Website-Hosting-Feature von S3 ändert dieses Verhalten: Es liefert den Inhalt mit den korrekten HTTP-Antwort-Headern, damit Browser ihn als richtige Webseite rendern, und liefert `index.html` automatisch, wenn ein Besucher die Root-URL aufruft.

**Ziel:** Füge eine `aws_s3_bucket_website_configuration`-Ressource zu `s3.tf` hinzu, die das statische Website-Hosting aktiviert und `index.html` als Index-Dokument festlegt. Nach dem Apply stellt S3 eine dedizierte **Website-Endpunkt-URL** bereit — nutze diese URL, um deine Website im Browser zu öffnen.

**Terraform-Dokumentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_website_configuration

<details>
<summary>Hinweis</summary>

`aws_s3_bucket_website_configuration` erfordert einen `index_document`-Block mit einem `suffix`-Argument, das auf `"index.html"` gesetzt ist.

Nach dem Apply ist der Website-Endpunkt als Attribut dieser Ressource verfügbar: `aws_s3_bucket_website_configuration.DEIN_LOKALER_NAME.website_endpoint`. Du kannst Terraform dazu bringen, ihn am Ende jedes `tf apply` automatisch auszugeben, indem du einen `output`-Block hinzufügst:

```hcl
output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.DEIN_LOKALER_NAME.website_endpoint}"
}
```

Führe `tf apply` erneut aus (Terraform bemerkt den neuen Output-Block) oder führe `tf output` aus, um alle Outputs ohne Änderungen auszugeben.

</details>

**Überprüfung:** Öffne die Website-Endpunkt-URL in deinem Browser. Du solltest eine animierte "It's Alive!"-Seite sehen. Wenn stattdessen ein XML "AccessDenied"-Fehler erscheint, gehe zurück zu Schritt 1.3 und überprüfe die Bucket-Policy und die Block-Public-Access-Einstellungen.

---

### Bonus – Website über CloudFront bereitstellen (HTTPS)

S3-Website-Endpunkte unterstützen nur einfaches HTTP. **CloudFront** ist das globale Content Delivery Network (CDN) von AWS. Es vor deinen S3-Bucket zu schalten, fügt HTTPS-Unterstützung und einen von CloudFront bereitgestellten Domainnamen hinzu — keine eigene Domain erforderlich.

Dies ist eine größere Aufgabe. Sie umfasst:

- Eine `aws_cloudfront_origin_access_control`-Ressource, damit CloudFront Objekte aus deinem Bucket über einen sicheren internen Kanal abrufen kann
- Eine `aws_cloudfront_distribution`-Ressource, konfiguriert mit deinem S3-Bucket als Origin
- Das Aktualisieren deiner Bucket-Policy, damit nur CloudFront auf den Bucket zugreifen kann, statt das öffentliche Internet direkt

**Terraform-Dokumentation:** https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution

---

## Aufgabe 2 – Wiederverwendung mit einem Terraform-Modul

Du hast jetzt eine funktionierende statische Website, die aus mehreren Terraform-Ressourcen besteht. Um eine zweite und dritte Website bereitzustellen, könntest du all diese Ressourcen kopieren — aber drei fast identische Kopien desselben Codes zu pflegen ist fehleranfällig und mühsam. Stattdessen extrahierst du das Setup in ein **wiederverwendbares Modul**.

### Was ist ein Modul?

Ein Modul ist schlicht ein Verzeichnis mit `.tf`-Dateien. Wenn deine Root-Konfiguration ein Modul aufruft, liest Terraform diese Dateien, als ob du sie direkt im Root geschrieben hättest — aber mit den von dir übergebenen Variablenwerten. Du definierst das Modul einmal und rufst es so oft wie nötig auf, jedes Mal mit anderen Eingaben. Stell es dir genau wie den Aufruf einer Funktion in einer Programmiersprache vor.

Dein Modul wird unter `terraform/modules/static-webpage/` liegen.

---

### 2.1 – Modulordnerstruktur erstellen

**Ziel:** Erstelle die folgenden zwei leeren Dateien:

```
terraform/modules/static-webpage/main.tf
terraform/modules/static-webpage/variables.tf
```

Es sind noch keine Terraform-Befehle erforderlich — diese sind nur leere Dateien, um die Struktur zu etablieren.

---

### 2.2 – Ressourcen in das Modul verschieben

**Ziel:** Schneide alle `aws_s3_*`-Ressourcen aus `terraform/s3.tf` aus und füge sie in `terraform/modules/static-webpage/main.tf` ein. Der `terraform {}`-Block, `provider`-Blöcke und `output`-Blöcke verbleiben in der Root-`main.tf` — kopiere diese nicht in das Modul.

Sobald die Ressourcen verschoben sind, kannst du `terraform/s3.tf` löschen.

> **Provider innerhalb von Modulen — wichtig:** Die Root-`main.tf` verwendet *aliasierte* Provider (`aws.frankfurt`). Ein Child-Modul muss explizit deklarieren, welche Provider-Aliases es erwartet. Füge den folgenden Block am Anfang von `terraform/modules/static-webpage/main.tf` hinzu:
>
> ```hcl
> terraform {
>   required_providers {
>     aws = {
>       source                = "hashicorp/aws"
>       configuration_aliases = [aws.frankfurt]
>     }
>   }
> }
> ```
>
> Dies teilt Terraform mit: "Dieses Modul erfordert einen Provider, der unter dem Alias `aws.frankfurt` konfiguriert ist." Du übergibst den tatsächlichen Provider, wenn du das Modul in Schritt 2.4 aufrufst.

---

### 2.3 – Eingabevariablen für das Modul deklarieren

Derzeit enthalten die Ressourcen im Modul hartcodierte Werte: deinen Bucket-Namen und den Dateipfad. Ersetze diese durch **Variablen**, damit das Modul bei jedem Aufruf mit unterschiedlichen Eingaben verwendet werden kann.

**Ziel:** Füge zwei Eingabevariablen zu `terraform/modules/static-webpage/variables.tf` hinzu:

| Variable | Typ | Beschreibung |
|----------|-----|--------------|
| `name` | `string` | Eine kurze Kennung für diese Website. Wird zur Konstruktion eines eindeutigen Bucket-Namens verwendet. |
| `filepath` | `string` | Der lokale Pfad zur hochzuladenden HTML-Datei, relativ zum Verzeichnis `terraform/`. |

Aktualisiere dann die Ressourcen in `main.tf` innerhalb des Moduls, um `var.name` und `var.filepath` statt der hartcodierten Werte zu verwenden.

**Terraform-Dokumentation:** https://developer.hashicorp.com/terraform/language/values/variables

<details>
<summary>Hinweis</summary>

Eine Variable wird mit einem `variable`-Block deklariert:

```hcl
variable "name" {
  description = "Eine kurze Kennung für diese Website-Bereitstellung."
  type        = string
}
```

Innerhalb der Ressourcendefinitionen des Moduls referenziere die Variable mit `var.name` und `var.filepath`.

Für den Bucket-Namen verknüpfe die Variable mit einem festen Präfix, um Namen über mehrere Modulaufrufe hinweg eindeutig zu halten. Zum Beispiel: `bucket = "workshop-${var.name}"`. Die `${}`-Syntax ist die String-Interpolation von Terraform — sie bettet den Wert eines Ausdrucks in einen String ein.

</details>

---

### 2.4 – Das Modul aus der Root-Konfiguration aufrufen

**Ziel:** Füge einen `module`-Block zu `terraform/main.tf` hinzu, der dein neues Modul aufruft und Werte für `name`, `filepath` und den Provider übergibt. Verwende die gleichen Werte, die du zuvor hartcodiert hattest (deine erste Website, `static-page`).

Nach dem Hinzufügen des Modul-Blocks führe zunächst `tf init` aus (erforderlich, wenn du einen neuen `module`-Block hinzufügst), dann `tf plan` und `tf apply`.

**Terraform-Dokumentation:** https://developer.hashicorp.com/terraform/language/modules/syntax

<details>
<summary>Hinweis</summary>

Ein Modulaufruf in `main.tf` sieht so aus:

```hcl
module "static_page_1" {
  source = "./modules/static-webpage"

  providers = {
    aws.frankfurt = aws.frankfurt
  }

  name     = "justus-static-page-1"
  filepath = "../resources/static-page/index.html"
}
```

- `source` ist der Pfad zum Modulverzeichnis, relativ zu `main.tf`.
- `providers` übergibt den Frankfurt-Provider-Alias in das Modul. Der Schlüssel (`aws.frankfurt`) entspricht der `configuration_aliases`-Deklaration, die du in Schritt 2.2 hinzugefügt hast; der Wert (`aws.frankfurt`) verweist auf den in der Root-`main.tf` konfigurierten Provider.
- `name` und `filepath` entsprechen den Variablen, die du in Schritt 2.3 deklariert hast.

**Denk daran:** `tf init` muss nach jedem neuen `module`-Block, der einen neuen `source`-Pfad einführt, erneut ausgeführt werden. Terraform verwendet init, um das Modul zu registrieren.

</details>

Wenn du in Schritt 1.4 einen `output`-Block hinzugefügt hast, verschiebe ihn in `terraform/modules/static-webpage/main.tf`. Um diesen Output auf Root-Ebene zugänglich zu machen, füge einen Output-Block in der Root-`main.tf` hinzu, der das Modul referenziert:

```hcl
output "website_url_1" {
  value = module.static_page_1.website_url
}
```

Damit dies funktioniert, muss das Modul selbst auch einen `output`-Block deklarieren, der `website_url` exponiert. Siehe: https://developer.hashicorp.com/terraform/language/values/outputs

---

### 2.5 – Zwei weitere Websites mit dem Modul bereitstellen

**Ziel:** Füge zwei weitere `module`-Blöcke zu `terraform/main.tf` hinzu — einen für jede der verbleibenden HTML-Dateien:

- `../resources/static-page-2/index.html`
- `../resources/static-page-3/index.html`

Gib jedem Modul-Block einen eindeutigen Namen (das erste Argument nach `module`) und einen eindeutigen `name`-Variablenwert, damit die S3-Bucket-Namen nicht kollidieren.

Führe `tf plan` aus und bestätige, dass Terraform plant, Ressourcen für beide neuen Websites zu erstellen. Dann führe `tf apply` aus.

**Überprüfung:** Öffne die Website-Endpunkt-URL für jeden der drei Buckets. Du solltest drei unterschiedliche Seiten sehen.

---

## Aufräumen

Wenn du mit dem Workshop fertig bist, entferne alle erstellten Ressourcen, um laufende AWS-Kosten zu vermeiden:

```bash
tf destroy
```

Terraform listet alles auf, was es löschen möchte, und fragt nach einer Bestätigung. Tippe `yes`, um fortzufahren. Warte, bis der Destroy abgeschlossen ist, bevor du dein Terminal schließt.

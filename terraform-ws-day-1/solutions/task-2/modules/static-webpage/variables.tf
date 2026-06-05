variable "name" {
  type        = string
  description = "Eine kurze Kennung für diese Website. Wird zur Konstruktion eines eindeutigen Bucket-Namens verwendet."
}

variable "filepath" {
  type        = string
  description = "Der lokale Pfad zur hochzuladenden HTML-Datei, relativ zum Verzeichnis terraform/."
}

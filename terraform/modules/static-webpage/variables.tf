variable "name" {
  default     = "juli-walkthrough1-workshop-static-page"
  description = "A short identifier for this website. Used to construct a unique bucket name."
  type        = string
}

variable "filepath" {
  default     = "../resources/static-page/index.html"
  description = "The local path to the HTML file to upload, relative to the terraform/ directory."
  type        = string
}
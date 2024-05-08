#create new bucket of standard type

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.24.0"
    }
  }
}

provider "google" {
  credentials = var.creds
  project = var.project
}

resource "google_storage_bucket" "static" {
  name = var.bucket_name
  location = var.location
  storage_class = var.class
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.static.id
  role = var.role
  member = var.scope
}

resource "google_storage_bucket_object" "default" {
  name = "sample_file.txt"
  source = "sample_file.txt"
  content_type = "text/plain"
  bucket = google_storage_bucket.static.id
}
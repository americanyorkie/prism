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
}

resource "google_service_account" "superuser_sa" {
  account_id   = var.superuser_id
  description = var.superuser_description
}

resource "google_project_iam_binding" "iam_sa_binding" {
  project = var.project
  role = "roles/resourcemanager.projectIamAdmin"

  members = [
    "serviceAccount:${google_service_account.superuser_sa.email}"
  ]

  resource "google_service_account_iam_binding" "impersonate_sa" {
    service_account_id = "google_service_account.superuser_sa.id"
    role = "roles/iam.serviceAccountTokenCreator"
  }

  members = [
    "user:${var.username}"
  ]
}

variable "project" {
	type = string
	description = "GCP project name TF will be applied in"
} 
variable "creds" {
	type = string
	description = "GCP credentials json file"
} 
variable "bucket_name" {
	type = string
	description = "Name of storage bucket"
} 
variable "location" {
	type = string
	description = "GCP region/location"
} 
variable "class" {
	type = string
	description = "Class of storage"
} 
variable "role" {
	type = string
	description = "Permissions granted IAM role assigned to storage bucket"
} 
variable "scope" {
	type = string
	description = "Identities granted privileges to utilise IAM role"
} 
variable "project" {
	type = string
	description = "GCP project name TF will be applied in"
} 
variable "creds" {
	type = string
	description = "GCP credentials json file"
} 
variable "id" {
	type = string
	description = ""
}
variable "description" {
	type = string
	description = ""
}
variable "role" {
	type = string
	description = "Permissions granted IAM role assigned to storage bucket"
} 
variable "scope" {
	type = string
	description = "Identities granted privileges to utilise IAM role"
} 
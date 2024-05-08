variable "creds" {
	type = string
	description = "GCP credentials json file"
} 
variable "project" {
	type = string
	description = "GCP project name TF will be applied in"
} 
variable "region" {
	type = string
	description = "GCP region"
} 
variable "zone" {
	type = string
	description = "GCP zone"
} 
variable "pem_filename" {
	type = string
	description = "Local filename to store pem file for ssh'ing into vm"
} 
variable "source_ssh_range" {
	type = string
	description = "CIDR for ssh access from local machine"
}
variable "internal_range" {
	type = string
	description = "CIDR for internal network connectivity"
}
variable "vm_name" {
	type = string
	description = "Identifier for vm"
} 
variable "machine_type" {
	type = string
	description = "GCP compute instance type"
} 
variable "image" {
	type = string
	description = "Base image used to build vm"
} 
variable "username" {
	type = string
	description = "Username for authn to vm"
} 
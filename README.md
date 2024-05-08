# prism
TF creation of GCP compute instance Ubuntu 20.06 with standalone MongoDB v5 

Self-hosted MongoDB v5 on GCP with Terraform

N.B. Project currently overly permissive and not secure - there are significant security flaws added intentionally. Further revisions needed to patch these.

Building a 3-tier architecture in GCP:

Storage - Cloud storage bucket for storing database backups.
Compute - vm using Ubuntu 20.04 built using TF, includes security groups, --Firewall rules to allow ssh access, open MongoDB default port --TLS key created via TF for ssh. Startup script starts and enables --MongoDB service. Backups of DB scripted via cron job and --stored in cloud storage bucket.
Web - Kubernetes cluster with web app pod, interfaces with MongoDB.

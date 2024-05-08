terraform {
	required_providers {
		google = {
			source = "hashicorp/google"
			version = "5.24.0"
		}
	}
}

provider "google" {
	credentials = file(var.creds)
	project = var.project
	region = var.region	
	zone = var.zone
}

provider "tls" {
}

resource "tls_private_key" "ssh-key" {
	algorithm = "RSA"
	rsa_bits = 4096
}

resource "local_file" "ssh_private_key_pem" {
	content = tls_private_key.ssh-key.private_key_pem
	filename = var.pem_filename
	file_permission = "0400"
}

resource "google_compute_firewall" "external-ssh-firewall" {
	name = "wiz-ex-external-ssh"
	network = "default"
	allow {
		protocol = "icmp"
	}
	source_ranges = [var.source_ssh_range]
	allow {
		protocol = "tcp"
		ports = ["22"]
	}
	target_tags = ["external-ssh"]
}

resource "google_compute_firewall" "mongodb-firewall" {
	name = "mongodb-access"
	network = "default"
	allow {
		protocol = "icmp"
	}
	source_ranges = [var.internal_range]
	allow {
		protocol = "tcp"
		ports = ["27017"]
	}
	target_tags = ["mongodb"]
}

resource "google_compute_address" "static" {
	name = "vm-public-ip"	
	depends_on = [google_compute_firewall.external-ssh-firewall]
}

resource "google_compute_instance" "db_vm" {
	name = var.vm_name
	machine_type = var.machine_type
	zone = var.zone
	tags = ["external-ssh", "mongodb"]
	boot_disk {
		initialize_params {
			image = var.image
		}
	}

	network_interface {
		network = "default"
		access_config {
			nat_ip = google_compute_address.static.address
		}
	}

	depends_on = [google_compute_firewall.external-ssh-firewall]

	metadata_startup_script = <<-MONGODB_INIT
		#!/bin/bash

		sudo apt-get clean; sudo apt update; 
		sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

		#Install latest version of gnupg and curl
		sudo apt-get -o DPkg::Lock::Timeout=600 -y install gnupg curl

		#Retrieve gpg key for MongoDB package verification
		curl -fsSL https://www.mongodb.org/static/pgp/server-6.0.asc | \
   		sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg \
   		--dearmor

 		#create list file for MongoDB 6.0
 		echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

 		sudo apt-get -o DPkg::Lock::Timeout=30 update
 		
 		#Pin MongoDB to v6.0.x
 		echo "mongodb-org hold" | sudo dpkg --set-selections
		echo "mongodb-org-database hold" | sudo dpkg --set-selections
		echo "mongodb-org-server hold" | sudo dpkg --set-selections
		echo "mongodb-mongosh hold" | sudo dpkg --set-selections
		echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
		echo "mongodb-org-tools hold" | sudo dpkg --set-selections

		#configure ulimit for mongod user
		echo "mongod soft     nproc          64000" >> /etc/security/limits.conf
		echo "mongod hard     nproc          64000" >> /etc/security/limits.conf
		echo "mongod soft     nofile         64000" >> /etc/security/limits.conf
		echo "mongod hard     nofile         64000" >> /etc/security/limits.conf

 		#For this exercise we're interested in using an old V of MongoDB
 		installs = $(sudo apt-get -o DPkg::Lock::Timeout=30 install -y mongodb-org=6.0.15 mongodb-org-database=6.0.15 mongodb-org-server=6.0.15 mongodb-org-mongos=6.0.15 mongodb-org-tools=6.0.15)

 		wait $installs
 		echo "MongoDB packages installed!"

 		# certificate installation 
		sudo touch /etc/ssl/mongodb.pem
		sudo touch /etc/ssl/mongodb-cert.crt
		sudo touch /etc/ssl/certs/mongodb-ca.crt
		sudo openssl req -newkey rsa:4096 -new -x509 -days 365 -nodes -subj '/C=GB/ST=Greater London/L=London/O=Personal/OU=Personal/emailAddress=<USER_EMAIL_ADDRESS>/CN=*.<DOMAIN_NAME>' -out mongodb-cert.crt -keyout mongodb-cert.key -addext 'subjectAltName=DNS:<HOSTNAME>'
		sudo cat mongodb-cert.key mongodb-cert.crt > mongodb.pem; sudo cp mongodb-cert.crt mongodb-ca.crt; sudo cp mongodb-cert.crt /etc/ssl/; sudo cp mongodb.pem /etc/ssl; sudo cp mongodb-ca.crt /etc/ssl/certs/
	
		sudo systemctl enable mongod
		sudo systemctl start mongod
		# mongodb user creation
		sudo cat <<-EOF > /home/${var.username}/user.js
		// user.js
		db.getSiblingDB("\$external").runCommand(
  		{
    		createUser: "user=<USER1>", pwd: '<PASSWORD>',
    		roles: [
      		{ role: "readWriteAnyDatabase", db: "admin" }
    		]
  		}
		)

		db.getSiblingDB("\$external").runCommand(
  		{
    		createUser: "user=<USER2>", pwd: '<PASSWORD>',
    		roles: [
      		{ role: "read", db: "admin" }
    		]
  		}
		)
		EOF

		sleep 1 
		sudo mongosh "127.0.0.1" /home/<USERNAME>/user.js
		sleep 4
		sudo mv /etc/mongod.conf{,.orig}
		sudo cat <<-EOF > /etc/mongod.conf
    storage:
      dbPath: /var/lib/mongodb
    security:
      authorization: enabled
    systemLog:
      destination: file
      logAppend: true
      path: /var/log/mongodb/mongod.log
    net:
      port: 27017
      bindIp: <HOSTNAME>
      tls:
        mode: requireTLS
        certificateKeyFile: /etc/ssl/mongodb.pem
        CAFile: /etc/ssl/mongodb-cert.crt
        allowConnectionsWithoutCertificates: true
    processManagement:
      timeZoneInfo: /usr/share/zoneinfo
		EOF
		sudo systemctl restart mongod

		#create backup dirs and cron job for backups
		sudo mkdir -p /opt/mongodump/dr_backup
		sudo mkdir /opt/mongodump/config
		sudo touch /opt/mongodump/config/secret.yaml
		sudo cat "${path.module}/secret.yaml" > /opt/mongodump/config/secret.yaml
		sudo cp /tmp/secret.yaml /opt/mongodump/config/secret.yaml
		sudo cp /tmp/mongo_dr_backup /etc/cron.hourly/mongo_dr_backup
		sudo cp /tmp/mongodb_backup.json ~/cli.json
		sudo touch /etc/cron.hourly/mongo_dr_backup
		sudo cat "${path.module}/mongo_dr_backup" > /etc/cron.hourly/mongo_dr_backup
		sudo chmod u+x /etc/cron.hourly/mongo_dr_backup
		sudo cat "${path.module}/gcloud_auth/mongodb_backup.json" > ~/cli.json

	MONGODB_INIT

	metadata = {
		ssh-keys = "${var.username}:${tls_private_key.ssh-key.public_key_openssh}"
	}
}

output "ip_address" {
  value = google_compute_address.static.address
}

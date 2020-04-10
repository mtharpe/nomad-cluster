////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Repo:           allstate/nomad
//  File Name:      main.tf
//  Author:         Patrick Gryzan
//  Company:        Hashicorp
//  Date:           April 2020
//  Description:    This is the main execution file
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

terraform {
    required_version = ">= 0.12.24"
}

locals {
    data_center             = "demo"
    consul_version          = "1.7.2"
    nomad_version           = "0.11.0"
    servers                 = "\"${join("\", \"", google_compute_instance.hashistack_server[*].network_interface.0.network_ip)}\""
    server_count            = length(google_compute_instance.hashistack_server[*].network_interface.0.network_ip)
}

provider "google" {
    credentials             = file(var.gcp.path)
    project                 = var.gcp.project
    region                  = var.gcp.region
    zone                    = var.gcp.zone
}

resource "google_compute_firewall" "default" {
    name                    = "demo-firewall"
    network                 = "default"

    allow {
        protocol            = "tcp"
        ports               = [ "22", "80", "443", "4646", "8500" ]
    }
}

resource "google_compute_instance" "hashistack_server" {
    count                   = var.hashistack.servers
    name                    = "hashistack-server-${count.index}"
    machine_type            = "n1-standard-2"

    boot_disk {
        initialize_params {
            image           = var.hashistack.image
            size            = var.hashistack.size
            type            = "pd-ssd"
        }
    }

    network_interface {
        network             = "default"
        access_config {
        }
    }
}

resource "null_resource" "hashistack_server_init" {
    count                   = var.hashistack.servers
    connection {
        type                = "ssh"
        host                = google_compute_instance.hashistack_server[count.index].network_interface.0.access_config.0.nat_ip
        user                = var.ssh.username 
        private_key         = file(var.ssh.private_key)
    }

    provisioner "file" {
        source              = "templates/hashistack-init.sh"
        destination         = "/tmp/hashistack-init.sh"
    }

    provisioner "remote-exec" {
        inline                  = [
            "chmod +x /tmp/hashistack-init.sh",
            "sudo /tmp/hashistack-init.sh -d '${local.data_center}' -c '${local.consul_version}' -n '${local.nomad_version}' -a 'server' -r '${local.servers}' -s ${local.server_count}",
            "sudo rm -r /tmp/hashistack-init.sh",
        ]
    }
}

resource "google_compute_instance" "hashistack_client" {
    count                   = var.hashistack.clients
    name                    = "hashistack-client-${count.index}"
    machine_type            = "n1-standard-2"

    boot_disk {
        initialize_params {
            image           = var.hashistack.image
            size            = var.hashistack.size
            type            = "pd-ssd"
        }
    }

    network_interface {
        network             = "default"
        access_config {
        }
    }

    depends_on              = [
        google_compute_instance.hashistack_server
    ]
}

resource "null_resource" "hashistack_client_init" {
    count                   = var.hashistack.clients
    connection {
        type                = "ssh"
        host                = google_compute_instance.hashistack_client[count.index].network_interface.0.access_config.0.nat_ip
        user                = var.ssh.username 
        private_key         = file(var.ssh.private_key)
    }

    provisioner "file" {
        source              = "templates/hashistack-init.sh"
        destination         = "/tmp/hashistack-init.sh"
    }

    provisioner "remote-exec" {
        inline                  = [
            "chmod +x /tmp/hashistack-init.sh",
            "sudo /tmp/hashistack-init.sh -d '${local.data_center}' -c '${local.consul_version}' -n '${local.nomad_version}' -a 'client' -r '${local.servers}' -s ${local.server_count}",
            "sudo rm -r /tmp/hashistack-init.sh",
        ]
    }
}
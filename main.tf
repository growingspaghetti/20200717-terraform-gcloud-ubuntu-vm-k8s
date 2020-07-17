terraform {
  backend "local" {
    path = ".private/terraform.tfstate"
  }
}

variable "region" {
  type    = string
  default = "europe-north1"
}

provider "google" {
  version     = "~> 3.30"
  credentials = file(".private/kubeadm20200717-fd53df3d62bd.json")
  project     = "kubeadm20200717"
  region      = var.region
}

resource "google_compute_network" "kubeadm" {
  name                    = "kubeadm"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kubeadm" {
  name          = "k8s-nodes"
  ip_cidr_range = "10.240.0.0/24"
  network       = google_compute_network.kubeadm.name
  region        = var.region
}

resource "google_compute_firewall" "allow-internal" {
  name    = "k8s-allow-internal"
  network = google_compute_network.kubeadm.name
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "ipip"
  }
  source_ranges = ["10.240.0.0/24"]
  target_tags   = ["k8s-node"]
}

resource "google_compute_firewall" "allow-external" {
  name    = "k8s-allow-external"
  network = google_compute_network.kubeadm.name
  allow {
    protocol = "tcp"
    ports    = ["22", "6443"] # kubernetes api
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["k8s-node"]
}

resource "google_compute_instance" "primary_node" {
  name         = "primary-node"
  machine_type = "n1-standard-1"
  zone         = "${google_compute_subnetwork.kubeadm.region}-a"
  tags         = ["k8s-node"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-focal-v20200701"
      size  = "10"
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.kubeadm.name
    access_config {
    }
  }

  metadata = {
    block-project-ssh-keys = "true"
    sshKeys                = file("~/.ssh/id_rsa.pub")
  }
}

provider "google" {
  credentials = file("/home/mkignito/sonata-gcp-users-1a23ae305cca.json")
  project     = "sonata-gcp-users"
  region      = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  name = "demo-vpc-network"
}

resource "google_compute_subnetwork" "public_subnet" {
  name          = "demo-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc_network.name
  region        = "us-central1"
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh-demo"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-demo"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000", "27017"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "jenkins-vm" {
  name         = "jenkins-vm"
  machine_type = "n1-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt update
    apt install -y default-jdk

    # Install Jenkins
    wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
    sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
    apt update
    apt install -y jenkins

    # Start Jenkins service
    systemctl start jenkins
    systemctl enable jenkins
  EOT

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      // Ephemeral IP
    }
  }
}

resource "google_compute_route" "public_subnet_route" {
  name        = "public-subnet-route-demo"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc_network.name
  next_hop_gateway = google_compute_instance.public_vm.network_interface[0].network_ip
}

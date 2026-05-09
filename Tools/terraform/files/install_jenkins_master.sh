#!/usr/bin/bash
set -euo pipefail

# ── Install Java (required for Jenkins) ──
sudo apt -y update
sudo apt install -y fontconfig openjdk-21-jre openjdk-21-jdk

# ── Install Jenkins (LTS) ──
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
  | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install -y jenkins

# ── Make Jenkins listen on 0.0.0.0 (all interfaces) instead of 127.0.0.1 ──
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_LISTEN_ADDRESS=0.0.0.0"
EOF

sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl restart jenkins


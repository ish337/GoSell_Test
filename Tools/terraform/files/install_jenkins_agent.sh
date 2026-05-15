#!/bin/bash
set -euo pipefail

AGENT_WORKDIR="/opt/jenkins-agent"

# Install Java
sudo apt update
sudo apt install openjdk-21-jre openjdk-21-jdk -y

# Install Docker
sudo apt install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Create jenkins user for agent
sudo useradd -m -d $${AGENT_WORKDIR} -s /bin/bash jenkins || true
sudo usermod -aG docker jenkins
sudo mkdir -p $${AGENT_WORKDIR}
sudo chown -R jenkins:jenkins $${AGENT_WORKDIR}

# Set SSH keys for master to agent connection
sudo mkdir -p $${AGENT_WORKDIR}/.ssh
sudo tee $${AGENT_WORKDIR}/.ssh/authorized_keys > /dev/null <<'KEYEOF'
${public_key}
KEYEOF

sudo chmod 700 $${AGENT_WORKDIR}/.ssh
sudo chmod 600 $${AGENT_WORKDIR}/.ssh/authorized_keys
sudo chown -R jenkins:jenkins $${AGENT_WORKDIR}/.ssh

echo "--- Jenkins Agent installation complete ---"
echo "SSH authorized_keys configured for jenkins user"
echo "Agent workdir: $${AGENT_WORKDIR}"
echo "Waiting for master to connect via SSH..."

#!/usr/bin/bash
set -euo pipefail

MASTER_IP="${master_ip}"
AGENT_SECRET="PLACEHOLDER"   # replace after first master boot — see notes at bottom
AGENT_NAME="agent-1"
AGENT_WORKDIR="/opt/jenkins-agent"
JENKINS_URL="http://$${MASTER_IP}:80"

# ── Install Java (required for the agent) ──
sudo apt -y update
sudo apt install -y openjdk-21-jre openjdk-21-jdk

# ── Install Docker ──
sudo apt install -y ca-certificates curl
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
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ── Create jenkins user for the agent ──
sudo useradd -m -d $${AGENT_WORKDIR} -s /bin/bash jenkins || true
sudo usermod -aG docker jenkins

# ── Download Jenkins agent.jar from the master ──
sudo mkdir -p $${AGENT_WORKDIR}
# Retry until master is up (it may still be booting)
for i in $(seq 1 30); do
  if sudo curl -fsSL "$${JENKINS_URL}/jnlpJars/agent.jar" -o $${AGENT_WORKDIR}/agent.jar; then
    echo "Downloaded agent.jar on attempt $${i}"
    break
  fi
  echo "Master not ready yet, retrying in 10s... ($${i}/30)"
  sleep 10
done
sudo chown -R jenkins:jenkins $${AGENT_WORKDIR}

# ── Create systemd service for Jenkins agent ──
sudo tee /etc/systemd/system/jenkins-agent.service <<UNIT
[Unit]
Description=Jenkins Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=jenkins
WorkingDirectory=$${AGENT_WORKDIR}
ExecStart=/usr/bin/java -jar $${AGENT_WORKDIR}/agent.jar \
    -url $${JENKINS_URL} \
    -name $${AGENT_NAME} \
    -secret $${AGENT_SECRET} \
    -workDir $${AGENT_WORKDIR}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent.service

# NOTE: The service is enabled but will fail to start until you:
#   1. Create a node named "agent-1" in Jenkins UI  (Manage Jenkins → Nodes → New Node)
#   2. Copy the agent secret from the Jenkins UI
#   3. SSH in and update AGENT_SECRET in /etc/systemd/system/jenkins-agent.service
#      (replace PLACEHOLDER with the real secret)
#   4. sudo systemctl daemon-reload && sudo systemctl restart jenkins-agent
#
# Alternatively, use the Jenkins "connect agent" instructions from the UI.

echo "=== Jenkins Agent installation complete ==="
echo "Agent configured to connect to master at $${JENKINS_URL}"
echo "Don't forget to set the real agent secret — see comments above."

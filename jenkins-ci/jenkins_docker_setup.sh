#!/bin/bash

# Instalar plugins
/usr/local/bin/install-plugins.sh < /usr/share/jenkins/ref/plugins.txt

# Instalar Terraform y AWS CLI
apt-get update && \
  apt-get install -y unzip curl gnupg python3 python3-pip zip software-properties-common lsb-release && \
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
  apt-get update && apt-get install -y terraform && \
  pip3 install awscli

# Lanzar Jenkins
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh

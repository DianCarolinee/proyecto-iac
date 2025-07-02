FROM jenkins/jenkins:lts

USER root

RUN apt-get update && apt-get install -y \
    unzip curl gnupg software-properties-common \
    python3 python3-pip zip sudo lsb-release

# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform

# AWS CLI
RUN pip3 install awscli

USER jenkins
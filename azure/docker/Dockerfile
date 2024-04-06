# Build azure container image for working with azure cli and 
#       kubernetes, helm kubectl etc
#FROM zenika/terraform-azure-cli:latest
# FROM bitnami/azure-cli:latest
FROM mcr.microsoft.com/azure-cli


ARG USER_NAME
ARG USER_ID
ARG ARCH
ARG TERRAFORM_VERSION
ARG BASHRC_FILE
ARG HELM_VERSION
 
USER root
#RUN apt-get update 
RUN apk update && apk add --no-cache bash bash-completion perl py3-ruamel.yaml curl unzip perl git make 
#RUN apk add  bash-completion perl py3-ruamel.yaml 
#    &&   pip3 install ruamel.yaml

# create a new user with the provided name and ID
RUN adduser -u $USER_ID -s /bin/bash -D $USER_NAME


WORKDIR /home/$USER_NAME
# install latest stable kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
    && chmod 755 ./kubectl \
    && mv kubectl /usr/local/bin

# Download and install Terraform for ${ARCH} architecture
RUN curl -L -o terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
  && unzip terraform.zip \
  && mv terraform /usr/local/bin/ \
  && rm terraform.zip 

RUN curl -L -o  helm.tar.gz https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz \ 
  && tar -zxvf ./helm.tar.gz \
  && mv linux-${ARCH}/helm /usr/local/bin/helm \ 
  && rm -rf helm.tar.gz linux-${ARCH}

USER $USER_NAME
RUN mkdir /home/$USER_NAME/work /home/$USER_NAME/terraform
COPY --chown=${USER_NAME}:${USER_NAME} install/bashrc /home/${USER_NAME}/.bashrc

# RUN  echo "export KUBECONFIG=$HOME/.kube/config" >> /home/$USER_NAME/.bashrc \
#     && echo "export PATH=/home/$USER_NAME/terraform:$PATH" >> /home/$USER_NAME/.bashrc \ 
#     && echo "alias k=kubectl " >>  /home/$USER_NAME/.bashrc  \
#     && echo "complete -F __start_kubectl k " >>  /home/$USER_NAME/.bashrc  \
#     && echo "alias ksetns=\"kubectl config set-context --current --namespace\" " >>  /home/$USER_NAME/.bashrc  \
#     && echo "alias ksetuser=\"kubectl config set-context --current --user\" "  >>   /home/$USER_NAME/.bashrc  \
#     && echo "PS1='\u\w:$ '" >>   /home/$USER_NAME/.bashrc \
#     && echo "alias cdaks='cd /terraform/aks'" >>   /home/$USER_NAME/.bashrc \ 
#     && echo "alias azlight='az config set core.theme=light'" >> /home/$USER_NAME/.bashrc 

ENTRYPOINT ["/bin/bash"]

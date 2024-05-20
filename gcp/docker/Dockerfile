# Build gcloud container image for working with GCP 
# include kubernetes, helm kubectl etc
# @see: https://cloud.google.com/sdk/docs/downloads-docker

FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine
RUN apk --update-cache add openjdk8-jre
RUN gcloud components install app-engine-java kubectl kustomize terraform-tools

ARG USER_NAME
ARG USER_ID
ARG ARCH
ARG TERRAFORM_VERSION
ARG BASHRC_FILE
ARG HELM_VERSION
 
USER root
RUN apk update && apk add --no-cache bash bash-completion perl py3-ruamel.yaml curl unzip perl git make 

# create a new user with the provided name and ID
RUN adduser -u $USER_ID -s /bin/bash -D $USER_NAME

WORKDIR /home/$USER_NAME
# install latest stable kubectl
# RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
#     && chmod 755 ./kubectl \
#     && mv kubectl /usr/local/bin

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
RUN mkdir /home/$USER_NAME/vnext /home/$USER_NAME/terraform 
COPY --chown=${USER_NAME}:${USER_NAME} install/bashrc /home/${USER_NAME}/.bashrc

ENTRYPOINT ["/bin/bash"]

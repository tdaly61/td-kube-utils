#!/usr/bin/env bash
# run the docker container built by the build.sh in this directory 
# which has azure cloud cli , terraform helm etc and this is to 
# simplify using terraform to build AKS clusters instances and other Azure artefacts
# Tom Daly:  Feb 2024


function check_image_exists_locally {
  docker image inspect $DOCKER_IMAGE_NAME > /dev/null 2>&1
  if [[ $? -ne 0 ]]; then 
    printf " ** Error: the docker image [ %s ] is not found locally \n" "$DOCKER_IMAGE_NAME"
    printf "    please run  [ %s ] to build it ** \n"  "$SCRIPT_DIR/build.sh"
    exit 
  fi 
}

function run_docker_container { 
  echo "Running $DOCKER_IMAGE_NAME container"
  docker run \
    --interactive --tty --rm \
    --volume "$(pwd)":/workspace \
    --volume "$HOME/td-terraform-dev/azure":/terraform \
    --volume "$HOME/mojafos":/mojafos \
    --volume "$HOME/.ssh":/home/$USER_NAME/.ssh \
    --env TERRAFORM_CLUSTER_DIR="/home/${USER_NAME}/vnext/platform-shared-tools/packages/installer/aws/terraform/$TERRAFORM_CLUSTER_DIR" \
    --hostname "$DOCKER_IMAGE_NAME" \
    --entrypoint=/bin/bash $DOCKER_IMAGE_NAME $@
} 

# echo "Running Azure and AKS container"
# echo "Running $DOCKER_IMAGE_NAME container"
# docker run \
#     --interactive --tty --rm \

#     --hostname "$DOCKER_IMAGE_NAME" \
#     $DOCKER_IMAGE_NAME $@


#### Set global env vars ####

SCRIPT_DIR=$( cd $(dirname "$0") ; pwd )
echo "SCRIPT_DIR : $SCRIPT_DIR"
HOST_TERRAFORM_DIR=$( cd $(dirname "$0")/../terraform ; pwd )
# point to the docker image that results from running build.sh 
DOCKER_IMAGE_NAME=`grep DOCKER_IMAGE_NAME $SCRIPT_DIR/build.sh | grep -v "\-t" | cut -d "\"" -f2 | awk '{print $1}'`
USER_NAME=$(whoami)
USER_ID=$(id -u $USER_NAME)

# printf "running azure  script [ %s ] from directory [ %s ] \n" $0 $SCRIPT_DIR
# printf "using docker image [ %s ] declared in [ %s ]  \n" "$DOCKER_IMAGE_NAME" "$SCRIPT_DIR/build.sh" 

#TERRAFORM_DIR=$HOME/opensource/td-terraform-dev/aws/terraform
#TERRAFORM_CLUSTER_DIR="aks" 

## run checks and then run the container 
check_image_exists_locally
run_docker_container



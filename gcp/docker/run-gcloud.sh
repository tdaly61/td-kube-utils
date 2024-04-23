#!/usr/bin/env bash
# run the docker container built by the build.sh in this directory 
# which has gcloud cli , terraform helm etc and this is to 
# simplify using terraform to build GKE clusters instances and other GCP artefacts
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
    --volume "$HOST_TERRAFORM_DIR":/terraform \
    --volume "$HOME/.config":"$HOME/.config" \
    --volume "$HOME/.kube":"$HOME/.kube" \
    --volume "$HOME/.ssh":/home/$USER_NAME/.ssh \
    --volume "$HOST_TD_KUBE_UTILS":$HOME/td-kube-utils \
    --hostname "$DOCKER_IMAGE_NAME" \
    --entrypoint=/bin/bash $DOCKER_IMAGE_NAME $@
} 

#### Set global env vars ####
SCRIPT_DIR=$( cd $(dirname "$0") ; pwd )
echo "SCRIPT_DIR : $SCRIPT_DIR"
HOST_TERRAFORM_DIR=$( cd $(dirname "$0")/../terraform ; pwd )
HOST_TD_KUBE_UTILS=$( cd $(dirname "$0")/../.. ; pwd )
echo "NDOGO LOOP = $HOST_NDOGO_LOOP_DIR"


# point to the docker image that results from running build.sh 
DOCKER_IMAGE_NAME=`grep DOCKER_IMAGE_NAME $SCRIPT_DIR/build.sh | grep -v "\-t" | cut -d "\"" -f2 | awk '{print $1}'`
USER_NAME=$(whoami)
USER_ID=$(id -u $USER_NAME)

## run checks and then run the container 
check_image_exists_locally
run_docker_container

# gcloud auth login -> does interactive auth
# gcloud config set project mojaloop-vnext
# gcloud container clusters get-credentials cluster-1 --zone europe-west2-a --project mojaloop-vnext
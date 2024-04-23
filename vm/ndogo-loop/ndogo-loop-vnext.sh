#!/usr/bin/env bash
# ndogo-loop.sh
#    - ndogo is Swahilli for "small" and ndogo-loop installs mojaloop vNext in a light-weight, 
#      simple and quick fashion for demo's testing and development.
#      my hope and plan is that this helps to make Mojaloop vNext accessible and cheap to learn
#      access and build skills required to run Mojaloop vNext in a cost efficent manner.
#   - ndogo-loop is NOT intended for production as it HA, proper security testing and more BUT 
#     it is intended to make available all the security features of Mojaloop vNext for you to learn and 
#     experiment with              
# Author Tom Daly 
# Date April 2024




################################################################################
# MAIN
################################################################################

# set global vars 
MLVN_DEPLOY_TARGET="" 
SCRIPTS_DIR="$( cd $(dirname "$0") ; pwd )"
TD_KUBE_UTILS_BASE_DIR="$( cd $(dirname "$SCRIPTS_DIR")/.. ; pwd )"
echo "TD_KUBE_UTILS_BASE_DIR=$TD_KUBE_UTILS_BASE_DIR"
NDOGO_LOOP_DIR="$TD_KUBE_UTILS_BASE_DIR/vm/ndogo-loop" 
COMMON_SCRIPTS_DIR="$NDOGO_LOOP_DIR/scripts"
echo "DBG> COMMON SCRIPTS_DIR X = $COMMON_SCRIPTS_DIR"
#echo "DBG> SCRIPTS_DIR X = $SCRIPTS_DIR"
REPO_BASE_DIR="$( cd $(dirname "$SCRIPTS_DIR")/../.. ; pwd )"
echo "DBG> REPO_BASE_DIR = $REPO_BASE_DIR"


VNEXT_LOCAL_REPO_DIR="$HOME/tmp/platform-shared-tools" 
VNEXT_GITHUB_REPO="https://github.com/mojaloop/platform-shared-tools" 
VNEXT_BRANCH="beta1"
MANIFESTS_DIR=$VNEXT_LOCAL_REPO_DIR/packages/installer/manifests
echo "DEBUG: MANIFESTS_DIR = $MANIFESTS_DIR" 
MONGO_IMPORT_DIR=$VNEXT_LOCAL_REPO_DIR/packages/deployment/docker-compose-apps/ttk_files/mongodb
MOJALOOP_CONFIGURE_FLAGS_STR=" -d $MANIFESTS_DIR " 
echo "DBG> MANIFESTS_DIR = $MANIFESTS_DIR"
LOGFILE="/tmp/$MLVN_DEPLOY_TARGET-install.log"
ERRFILE="/tmp/$MLVN_DEPLOY_TARGET-install.err"

# read in the functions and common global vars
source $COMMON_SCRIPTS_DIR/shared-functions.sh 
# read in the main mojaloop install function 
source $COMMON_SCRIPTS_DIR/install.sh 

set_deploy_target  # deploy targets are ndogo-loop, AKS as at April 2024

# Process command line options as required
while getopts "d:m:t:l:o:hH" OPTION ; do
   case "${OPTION}" in
        n)  nspace="${OPTARG}"
        ;;
        l)  logfiles="${OPTARG}"
        ;;
        t)  tsecs="${OPTARG}"
        ;;
        d)  domain_name="${OPTARG}"
            echo "-d flag is TBD"
            exit 1 
        ;; 
        m)  mode="${OPTARG}"
        ;;
        o)  install_opt="${OPTARG}"
        ;; 
        h|H)	showUsage
                exit 0
        ;;
        *)	echo  "unknown option"
                showUsage
                exit 1
        ;;
    esac
done


# clone vnext deployment repo called platform-shared-tools locally if not already done
# or if locally modified 
clone_if_needed  $VNEXT_GITHUB_REPO $VNEXT_LOCAL_REPO_DIR $VNEXT_BRANCH

# call the common install script to install Mojaloop vNext into the kubernetes cluster
install_vnext $MLVN_DEPLOY_TARGET

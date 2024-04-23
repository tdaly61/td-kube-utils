#!/usr/bin/env bash
# create-aks-cluster.sh 
# - script to run Terraform
# Nov 2023 
# Author Tom Daly 

# make sure user is authenticated via MFA to AWS 
function verify_credentials {
  printf "==> verify credentials are current using aws-mfa ...        "
  timeout 2 aws-mfa > /dev/null 2>&1 
  if [[ $? -eq 0 ]]; then 
    printf "[ok]\n"
  else 
    printf "\n** Error : please update cedentials using aws-mfa utility ** \n"
    exit 1
  fi  
}

function configure_kubectl {
  printf "==> configuring kubectl access to cluster...    "
  # Store the current directory
  local current_dir=$(pwd)
  cd $TF_TOP_DIR/aks-setup
  local region=`grep region $TF_TOP_DIR/env.hcl | cut -d "=" -f2 | tr -d "\"" | tr -d " "`
  local cluster=`terraform output -raw cluster_name`
  aws aks --region $region update-kubeconfig --name $(terraform output -raw cluster_name) > /dev/null 2>&1 
  working=`kubectl get nodes | grep -i notready | wc -l` 
  echo "working is : $working" 
  if [[ $? -eq 0 ]]; then 
    printf "[ok]\n"
  else 
    printf "\n    *** warning   : kubectl access to the cluster [%s] is not working \n" $CLUSTER_NAME
    printf "        try running kubectl get nodes  \n"
    printf "    ***\n"
    exit 1
  fi 
}

function validate_tfdir {
    local tfdir=$1 
    if [[ "$tfdir" == "backend" ]] || [[ "$tfdir" == "aks-setup" ]] || [[ "$tfdir" == "addons" ]] ; then 
        return
    else 
        echo "got an invalid directory" 
        printf "** Error unrecognised value for -d  ** \n" 
        showUsage
    fi 
}

function set_cluster_name {
    # the aks-setup/aks.tf uses the name and environment from the env.hcl and 
    # creates a cluster name of name-evironment-cluster 
    name=`grep ^name $TF_VAR_FILE | cut -d "=" -f2 | tr -d " " | tr -d "\""`
    environment=`grep ^environment $TF_VAR_FILE | cut -d "=" -f2 | tr -d " " | tr -d "\""`

    # Construct the CLUSTER_NAME variable
    CLUSTER_NAME="${name}-${environment}-cluster"
}

# Function to run Terraform commands
function run_terraform {
    local directory="$1"
    local action="$2"

    # Store the current directory
    local current_dir=$(pwd)

    echo "dir is $directory" 
    # Change to the specified directory
    cd "$directory" || { echo "Error: Unable to change directory to $directory. Exiting..."; exit 1; }
    
    # Initialize Terraform
    echo "directory is $directory"
    terraform init

    # Run Terraform command based on the specified action
    if [ "$action" == "apply" ]; then
        # Run Terraform plan with the common HCL configuration file and output to a plan file
        echo "==============================================================================="
        echo "INFO: Running Terraform plan for $directory..."
        echo "==============================================================================="
        terraform plan -out=tfplan
        
        # Check for errors in the plan
        if [ $? -eq 0 ]; then
            # Apply the Terraform plan
            echo "==============================================================================="
            echo "INFO: Applying Terraform plan for $directory..."
            echo "==============================================================================="
            terraform apply tfplan -compact-warnings
        else
            echo "Error: Terraform plan failed. Exiting..."
            exit 1
        fi
        if [ `basename "$directory"` == "aks-setup" ]; then 
            configure_kubectl 
        fi 
    elif [ "$action" == "destroy" ]; then
        echo "==============================================================================="
        echo "INFO: Destroying Terraform resources for $directory..."
        echo "==============================================================================="
        terraform destroy --auto-approve 
    else
        echo "Error: Invalid action specified. Use '--apply' for apply or '--destroy' for destroy."
        exit 1
    fi

    # Return to the original directory
    cd "$current_dir" || exit 1
}

################################################################################
# Function: showUsage
################################################################################
function showUsage {
    echo  "USAGE: $0 -m [mode] -d [tfdir]
    Example 1 : $0 -m create  # create aks cluster 
    Example 2 : $0 -m destroy # destroy the  existing aks cluster 
    Example 3 : $0 -m apply -d backend  # apply terraform for backend only 

    Options:
    -m mode ............... create|destroy  (-m is required)
    -d tf directory ....... backend|aks-setup|addons  
    -h|H .................. display this message

    Note: order is important if using -d 
    create in this order              destroy in this order           
    1. backend                        addons 
    2. aks-setup                      aks-setup
    3. addons                         backend 

    this will help to ensure resources clean up properly from AWS 
    "
}

################################################################################
# MAIN
################################################################################
SCRIPT_DIR="$( cd $(dirname "$0") ; pwd )"
echo "SCRIPT_DIR = $SCRIPT_DIR"
TF_TOP_DIR=$VNEXT_REPO_BASE_DIR/packages/installer/aws/terraform/aks
echo "TERRAFORM_DIR = $TF_TOP_DIR"

# Common HCL configuration file
TF_VAR_FILE="$TF_TOP_DIR/env.hcl"
echo "TF_VAR_FILE=$TF_VAR_FILE"

TF_SUB_DIRS=("backend" "aks-setup" "addons")  # subdirectories for terraform 
CLUSTER_NAME=""
CLUSTER_EXISTS=""

# Check for valid input parameters
if [ "$#" -eq 0 ]; then
    showUsage
fi
# Process command line options as required
while getopts "m:d:hH" OPTION ; do
   case "${OPTION}" in
        m)	    mode="${OPTARG}"
        ;;
        d)	    tfdir="${OPTARG}"
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

if [[ ! -z "$tfdir" ]]; then 
    validate_tfdir $tfdir
fi 

printf "\n\n*********************************************************************************\n"
printf "            -- AWS aks managed kubernetes cluster -- \n"
printf "  utilities for deploying kubernetes in preparation for Mojaloop (vNext) deployment   \n"
printf "************************* << start >> ***********************************************\n\n"

set_cluster_name
verify_credentials

if [[ "$mode" == "create" ]]; then
    if [[ ! -z "$tfdir" ]]; then 
        printf "==> Running terraform [%s] in directory [%s] ... \n" "$mode" "$TF_TOP_DIR/$tfdir"
        echo "calling run_terraform apply  $tfdir"
        run_terraform "$TF_TOP_DIR/$tfdir" "apply"
    else 
        printf "==> Creating  Cluster [%s] in directory [%s] ... \n" $CLUSTER_NAME $TF_TOP_DIR
        for dir in "${TF_SUB_DIRS[@]}"; do
            echo "run_terraform "$TF_TOP_DIR/$dir" "apply"" 
            printf "    > run tf apply on [%s]\n" $dir
        done
    fi 
elif [[ "$mode" == "destroy" ]]; then  
    if [[ ! -z "$tfdir" ]]; then 
        printf "==> Running terraform [%s] in directory [%s] ... \n" "$mode" "$TF_TOP_DIR/$tfdir"
        run_terraform "$TF_TOP_DIR/$tfdir" "destroy"
    else 
        printf "==> Destroying  Cluster [%s] in directory [%s] ... \n" $CLUSTER_NAME $TF_TOP_DIR
        # destroy in the reverse order 
        for ((i=${#TF_SUB_DIRS[@]}-1; i>=0; i--)); do
            printf "    > run tf destory on [%s]\n" ${TF_SUB_DIRS[$i]}
            #run_terraform "$TF_TOP_DIR/${TF_SUB_DIRS[$i]}" "destroy"
        done    
    fi
else 
    printf "** Error unrecognised value for -m  ** \n" 
    showUsage
fi

# while [ "$#" -gt 0 ]; do
#     case "$1" in
#         "--apply") 
#             shift
#             if [ -n "$1" ]; then
#                 run_terraform "$TF_TOP_DIR/$1" "apply"
#             else
#                 # Process all directories for apply
#                 for dir in "${TF_SUB_DIRS[@]}"; do
#                     run_terraform "$TF_TOP_DIR/$dir" "apply"
#                 done
#             fi
#             ;;
#         "--destroy")
#             shift
#             if [ -n "$1" ]; then
#                 run_terraform "$TF_TOP_DIR/$1" "destroy"
#             else
#                 # Process all directories for destroy in reverse order
#                 for ((i=${#TF_SUB_DIRS[@]}-1; i>=0; i--)); do
#                     echo "directory is $TF_TOP_DIR/${TF_SUB_DIRS[$i]}"
#                     run_terraform "$TF_TOP_DIR/${TF_SUB_DIRS[$i]}" "destroy"
#                 done
#             fi
#             ;;
#         "-h" | "--help")
#             usage
#             ;;
#         *)
#             echo "Error: Invalid option. Use '-h' or '--help' for usage information."
#             exit 1
#             ;;
#     esac
#     shift
# done

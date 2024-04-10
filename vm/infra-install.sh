# infra-install.sh 
# install a selection of databases,messaging services 
# messaging and monitorng services 
# commonly used with open source kubernetes applications 
# T Daly 
# April 2024

function infra_install {
  local deploy_target="$1"
  record_memory_use "at_start"
  print_start_banner $deploy_target
  get_arch_of_nodes
  if [[ $deploy_target == "ndogo-loop" ]]; then 
    check_not_inside_docker_container   # ndogo-loop only 
    set_arch  
    set_k8s_distro  
    #check_arch   # ndogo-loop only 
  elif [[ $deploy_target == "AWS" ]]; then 
    check_access_to_cluster  # eks only 
  fi 
  check_repo_owner_not_root $REPO_BASE_DIR
  check_user
  set_k8s_version 
  check_k8s_version_is_current 
  set_logfiles 
  set_and_create_namespace 
  set_mojaloop_vnext_timeout
  printf "\n"

  if  [[ "$mode" == "update_images" ]]; then
    print "<<<< for development only >>>>>\n"
    update_k8s_images_from_docker_files 
    printf "<<<< for development only >>>>>\n"
  elif [[ "$mode" == "delete_ml" ]]; then
    delete_mojaloop_vnext_layer "ttk" $MANIFESTS_DIR/ttk
    delete_mojaloop_vnext_layer "reporting" $MANIFESTS_DIR/reporting
    delete_mojaloop_vnext_layer "apps" $MANIFESTS_DIR/apps
    delete_mojaloop_vnext_layer "crosscut" $MANIFESTS_DIR/crosscut
    delete_mojaloop_vnext_infra_release  
    print_end_banner $deploy_target
  elif [[ "$mode" == "install_ml" ]]; then
    tstart=$(date +%s)
    printf "     <start> :  Mojaloop (vNext) install utility [%s]\n" "`date`" >> $LOGFILE
    #configure_extra_options 
    
    copy_k8s_yaml_files_to_tmp
    source $HOME/mlenv/bin/activate 
    modify_local_mojaloop_vnext_yaml_and_charts  "$COMMON_SCRIPTS_DIR/configure.py" "$MANIFESTS_DIR"
    install_infra_from_local_chart $MANIFESTS_DIR/infra
    check_urls
    tstop=$(date +%s)
    telapsed=$(timer $tstart $tstop)
    timer_array[install_ml]=$telapsed
    print_stats
    print_success_message 
    print_end_banner $deploy_target
  else 
    printf "** Error : wrong value for -m ** \n\n"
    showUsage
    exit 1
  fi 

}

################################################################################
# MAIN
################################################################################

# set global vars 
MLVN_DEPLOY_TARGET="" 
SCRIPTS_DIR="$( cd $(dirname "$0") ; pwd )"
TD_KUBE_UTILS_BASE_DIR="$( cd $(dirname "$SCRIPTS_DIR")/.. ; pwd )"
echo "TD_KUBE_UTILS_BASE_DIR=$TD_KUBE_UTILS_BASE_DIR"
COMMON_SCRIPTS_DIR="$NDOGO_LOOP_DIR/scripts"
echo "DBG> COMMON SCRIPTS_DIR X = $COMMON_SCRIPTS_DIR"
#echo "DBG> SCRIPTS_DIR X = $SCRIPTS_DIR"
REPO_BASE_DIR="$( cd $(dirname "$SCRIPTS_DIR")/../.. ; pwd )"
echo "DBG> REPO_BASE_DIR = $REPO_BASE_DIR"

MANIFESTS_DIR=$VNEXT_LOCAL_REPO_DIR/packages/installer/manifests
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

#!/usr/bin/env bash
# k8s-install.sh : install kubernetes k3s or microk8s on local (ubuntu) os 
# Author:  Tom Daly 
# Date :   April 2024 

function check_pi {
    # this is to enable experimentation on raspberry PI which is WIP
    if [ -f "/proc/device-tree/model" ]; then
        model=`cat /proc/device-tree/model | cut -d " " -f 3`
        printf "** Warning : hardware is Raspberry PI model : [%s] \n" $model
        printf " for Ubuntu 20 need to append  cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 to /boot/cmdline.txt \n"
        printf " and reboot the PI ** \n"     
    fi 
}

function check_arch_ok {
    if [[ "$k8s_arch" == "aarch64" ]] || [[ "$k8s_arch" == "arm64" ]] ; then
        k8s_arch="arm64"
    fi 
    if [[ ! "$k8s_arch" == "x86_64" ]] && [[ ! "$k8s_arch" == "arm64" ]]  ; then 
        printf "** Error: unrecognised architecture [%s] \n" $k8s_arch
        printf "   currently x86_64 or arm64 are tested \n"
        exit  
    fi
} 

# function check_resources_ok {
#     # Get the total amount of installed RAM in GB
#     total_ram=$(free -g | awk '/^Mem:/{print $2}')
#     # Get the current free space on the root filesystem in GB
#     free_space=$(df -BG /home/"$k8s_user" | awk '{print $4}' | tail -n 1 | sed 's/G//')

#     # Check RAM 
#     if [[ "$total_ram" -lt "$MIN_RAM" ]]; then
#         printf " ** Error :currently minimum ram is set to $MIN_RAM GBs \n"
#         exit 1 
#     fi
#     # Check free space 
#         if [[  "$free_space" -lt "$MIN_FREE_SPACE" ]] ; then
#         printf " ** Warning : currently min free disk is set to %sGBs in %s home directory  \n"  "$MIN_FREE_SPACE" "$k8s_user"
#         printf "    but only found %sGBs free storage \n"  "$free_space"
#         printf "    installation will continue , but beware it might fail later due to insufficient storage \n"
#     fi
# } 

# function set_user {
#   # set the k8s_user 
#   k8s_user=`who am i | cut -d " " -f1`
# }

function k8s_already_installed {  
    if [[ -f "/usr/local/bin/k3s" ]]; then 
        printf "** Error , k3s is already installed , please delete before reinstalling kubernetes  **\n"
        exit 1
    fi 
    #check to ensure microk8s isn't already installed when installing k3s
    if [[ -f "/snap/bin/microk8s" ]]; then 
        printf "** Error , microk8s is already installed, please delete before reinstalling kubernetes  **\n"
        exit 1
    fi 
}

# function set_linux_os_distro {
#     if [ -x "/usr/bin/lsb_release" ]; then
#         LINUX_OS=`lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/' `
#         LINUX_VERSION=`/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/' `
#     else
#         LINUX_OS="Untested"
#     fi 
#     printf "==> Linux OS is [%s] version [ %s ] " "$LINUX_OS" "$LINUX_VERSION"

# }

# function determine_os {
#     if [[ "$(uname)" == "Darwin" ]]; then
#         echo "macOS"
#     elif [[ -x "/usr/bin/lsb_release" && "$(lsb_release -si)" == "Ubuntu" ]]; then
#         echo "Ubuntu"
#     else
#         echo "Unknown"
#     fi
# }

#### New 
check_os() {
    #declare -A os_dict
    os_dict=([Ubuntu]="22.04" [MacOS]="13.5")

    current_os=$(uname -s)
    current_release=""

    if [[ "$current_os" == "Linux" ]]; then
        # Check if it's Ubuntu
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            if [[ "$ID" == "ubuntu" ]]; then
                current_release=$(echo $VERSION_ID | cut -d. -f1,2)
            fi
        fi
    elif [[ "$current_os" == "Darwin" ]]; then
        current_os="MacOS"
        current_release=$(sw_vers | grep ProductVersion | cut -d':' -f2 | tr -d '\t' | awk -F'.' '{print $1"."substr($2,1,1)}')
    else
        echo "Error: Unsupported operating system: $current_os"
        exit 1
    fi

    if [[ -n "${os_dict[$current_os]}" && "${os_dict[$current_os]}" == "$current_release" ]]; then
        echo "Discovered operating system: $current_os"
        echo "Version: $current_release"
        echo "Current operating system $current_os $current_release is supported."
    else
        echo "Error: Current operating system $current_os $current_release is not supported."
        exit 1
    fi

    CURRENT_OS=$current_os
    CURRENT_VERSION=$current_release    
}

check_system_resources() {
    current_os=$1
    min_free_ram=$2
    min_free_disk=$3
    
    if [[ "$current_os" == "Linux" ]]; then
        total_ram=$(free -m | awk '/^Mem:/ {print $2}')
        free_ram=$(free -m | awk '/^Mem:/ {print $4}')
        free_space=$(df -h --output=avail / | tail -n 1 | awk '{print $1}')
    elif [[ "$current_os" == "Darwin" ]] || [[ "$current_os" == "MacOS" ]]; then
        total_ram=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024)}')
        free_ram=$(vm_stat | awk '/Pages free/ {print $3*4096/1024/1024}')
        free_space=$(df -h / | tail -n 1 | awk '{print $4}')
    else
        printf "Error: Unsupported operating system: %s\n" "$current_os"
        exit 1
    fi

    printf "Total RAM: %s MB\n" "$total_ram"
    printf "Free RAM: %.2f GB\n" "$(bc <<< "scale=2; $free_ram/1024" | sed 's/Gi//')"
    printf "Free Space: %s\n" "$free_space"

    # Remove units from free RAM and disk space and convert to integers
    free_ram=$(echo "$free_ram" | sed 's/Gi//')
    free_space=$(echo "$free_space" | sed 's/Gi//')

    # Check if free RAM and disk space meet the minimum requirements
    if (( $(echo "$free_ram >= $min_free_ram" | bc) && $(echo "$free_space >= $min_free_disk" | bc) )); then
        printf "System meets minimum requirements.\n"
    else
        printf "Error: System does not meet minimum requirements.\n"
        exit 1
    fi
}


### end new ##


# function check_os_ok {
#     printf "==> checking OS and kubernetes distro is tested with install scripts\n"
#     set_linux_os_distro
#     if [[ ! $LINUX_OS == "Ubuntu" ]]; then
#         printf "** Error , install script is only tested with Ubuntu OS at this time   **\n"
#         exit 1
#     fi 
#     local os_version_ok=false
#     for i in "${UBUNTU_OK_VERSIONS_LIST[@]}"; do
#         if  [[ "$LINUX_VERSION" == "$i" ]]; then
#             os_version_ok=true
#             break
#         fi  
#     done
#     if [[ ! "$os_version_ok" == true ]]; then 
#         printf "** Error , install scripts are not tested with Ubuntu OS version [ %s ] at this time \n" "$LINUX_VERSION"
#         printf "           current tested Ubuntu versions are :-  " 
#         printf " [ %s ] " "${UBUNTU_OK_VERSIONS_LIST[@]}"
#         printf "   **\n" 
#         exit 1
#     fi 
# } 

function install_prerequisites {
    printf "==> Install any OS prerequisites , tools &  updates  ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then  
        printf "    apt update \n"
        apt update > /dev/null 2>&1
        printf "    python and python libs ...\n"
        apt install python3-pip -y > /dev/null 2>&1
        apt install python3.10-venv -y > /dev/null 2>&1
        su - $k8s_user -c "pip3 install --user virtualenv" 
        su - $k8s_user -c "python3 -m venv $k8s_user_home/mlenv"
        su - $k8s_user -c "source $k8s_user_home/mlenv/bin/activate; pip3 install ruamel.yaml "
        #pip3 install ruamel.yaml > /dev/null 
        if [[ $k8s_distro == "microk8s" ]]; then 
            printf "   install snapd\n"
            apt install snapd -y > /dev/null 2>&1
        fi
    fi 
}

function set_k8s_distro { 
    if [ -z ${k8s_distro+x} ]; then  
        k8s_distro=$DEFAULT_K8S_DISTRO
        printf "==> Using default kubernetes distro [%s]\n" "$k8s_distro"
    else 
        k8s_distro=`echo "$k8s_distro" | perl -ne 'print lc'`
        if [[ "$k8s_distro" == "microk8s" || "$k8s_distro" == "k3s" ]]; then 
            printf "==> kubernetes distro set to [%s] \n" "$k8s_distro"
        else 
            printf "** Error : invalid kubernetes distro specified. Valid options are microk8s or k3s \n"
            exit 1
        fi
    fi
}

function print_current_k8s_releases {
    printf "          Current Kubernetes releases are : " 
    for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
        printf " [v%s]" "$i"
    done
    printf "\n"
}

function set_k8s_version {
    # printf "========================================================================================\n"
    # printf " set the k8s version to install  \n"
    # printf "========================================================================================\n\n"
    if [ ! -z ${k8s_user_version+x} ] ; then
        # strip off any leading characters
        k8s_user_version=`echo $k8s_user_version |  tr -d A-Z | tr -d a-z `
        for i in "${K8S_CURRENT_RELEASE_LIST[@]}"; do
            if  [[ "$k8s_user_version" == "$i" ]]; then
                CURRENT_RELEASE=true
                break
            fi  
        done
        if [[ $CURRENT_RELEASE == true ]]; then     
            K8S_VERSION=$k8s_user_version
        else 
            printf "** Error: The specified kubernetes release [ %s ] is not a current release \n" "$k8s_user_version"
            printf "          when using the -v flag you must specify a current supported release \n"
            print_current_k8s_releases 
            printf "** \n"
            exit 1 
        fi 
    else 
        printf "** Error: kubernetes release has not been specified with the -v flag  \n" 
        printf "          you must supply the -v flag and specify a current supported release \n\n"
        showUsage
        exit 1
    fi 
    printf "==> kubernetes version to install set to [%s] \n" "$K8S_VERSION"
}

function do_microk8s_install {
    # TODO : Microk8s can complain that This is insecure. Location: /var/snap/microk8s/2952/credentials/client.config
    printf "==> Installing Kubernetes MicroK8s & enabling tools (helm,ingress  etc) \n"

    echo "==> Microk8s Install: installing microk8s release $k8s_user_version ... "
    # ensure k8s_user has clean .kube/config 
    rm -rf $k8s_user_home/.kube >> /dev/null 2>&1 

    snap install microk8s --classic --channel=$K8S_VERSION/stable
    microk8s.status --wait-ready
    microk8s.enable helm3 
    microk8s.enable dns
    echo "==> enable storage ... "
    microk8s.enable storage
    microk8s.enable ingress

    echo "==> add convenient aliases..." 
    snap alias microk8s.kubectl kubectl
    snap alias microk8s.helm3 helm

    echo "==> add $k8s_user user to microk8s group"
    usermod -a -G microk8s $k8s_user

    # ensure .kube/config points to this new cluster and KUBECONFIG is not set in .bashrc
    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bash_profile
    chown -f -R $k8s_user $k8s_user_home/.kube
    microk8s config > $k8s_user_home/.kube/config
}

function do_k3s_install {
    printf "========================================================================================\n"
    printf "k3s install : Installing Kubernetes k3s engine and tools (helm/ingress etc) \n"
    printf "========================================================================================\n"
    # ensure k8s_user has clean .kube/config 
    echo "DEBUG k8s user is : $k8s_user"
    rm -rf $k8s_user_home/.kube >> /dev/null 2>&1 
    printf "==> installing k3s "
    #echo $K8S_VERSION
    curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="644" \
                            INSTALL_K3S_CHANNEL="v$K8S_VERSION" \
                            INSTALL_K3S_EXEC=" --disable traefik " sh 

    # check k3s installed ok 
    status=`k3s check-config 2> /dev/null | grep "^STATUS" | awk '{print $2}'  ` 
    if [[ "$status" -eq "pass" ]]; then 
        printf "[ok]\n"
    else
        printf "** Error : k3s check-config not reporting status of pass   ** \n"
        printf "   run k3s check-config manually as user [%s] for more information   ** \n" "$k8s_user"
        exit 1
    fi

    # configure user environment to communicate with k3s kubernetes
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    cp /etc/rancher/k3s/k3s.yaml  $k8s_user_home/k3s.yaml
    chown $k8s_user  $k8s_user_home/k3s.yaml
    chmod 600  $k8s_user_home/k3s.yaml 

    perl -p -i.bak -e 's/^.*KUBECONFIG.*$//g' $k8s_user_home/.bashrc
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >>  $k8s_user_home/.bashrc
    perl -p -i.bak -e 's/^.*source .bashrc.*$//g' $k8s_user_home/.bash_profile 
    perl -p  -i.bak2 -e 's/^.*export KUBECONFIG.*$//g' $k8s_user_home/.bash_profile 
    echo "source .bashrc" >>   $k8s_user_home/.bash_profile 
    echo "export KUBECONFIG=\$HOME/k3s.yaml" >> $k8s_user_home/.bash_profile  
    
    # install helm
    printf "==> installing helm " 
    helm_arch_str=""
    if [[ "$k8s_arch" == "x86_64" ]]; then 
        helm_arch_str="amd64"
    elif [[ "$k8s_arch" == "aarch64" ]] || [[ "$k8s_arch" == "arm64" ]]; then 
        helm_arch_str="arm64"
    else 
        printf "** Error:  architecture not recognised as x86_64 or arm64  ** \n"
        exit 1
    fi
    rm -rf /tmp/linux-$helm_arch_str /tmp/helm.tar
    curl -L -s -o /tmp/helm.tar.gz https://get.helm.sh/helm-v$HELM_VERSION-linux-$helm_arch_str.tar.gz
    gzip -d /tmp/helm.tar.gz 
    tar xf  /tmp/helm.tar -C /tmp
    mv /tmp/linux-$helm_arch_str/helm /usr/local/bin  
    rm -rf /tmp/linux-$helm_arch_str
    /usr/local/bin/helm version > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then 
        printf "[ok]\n"
    else 
        printf "** Error : helm install seems to have failed ** \n"
        exit 1
    fi
    
    #install nginx
    printf "==> installing nginx ingress chart and wait for it to be ready " 
    su - $k8s_user -c "helm install --wait --timeout 300s ingress-nginx ingress-nginx \
                      --repo https://kubernetes.github.io/ingress-nginx \
                      -f $TD_KUBE_UTILS_BASE_DIR/manifests/nginx-values.yaml" 
    # TODO : check to ensure that the ingress is indeed running 
    nginx_pod_name=$(kubectl get pods | grep nginx | awk '{print $1}')

    if [ -z "$nginx_pod_name" ]; then
        printf "** Error : helm install of nginx seems to have failed , no nginx pod found ** \n"
        exit 1
    fi
    # Check if the Nginx pod is running
    if kubectl get pods $nginx_pod_name | grep -q "Running"; then
        printf "[ok]\n"
    else
        printf "** Error : helm install of nginx seems to have failed , nginx pod is not running  ** \n"
        exit 1
    fi

}

function install_k8s_tools { 
    printf "==> install kubernetes tools, kubens, kubectx kustomize \n" 
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubens_v0.9.4_linux_x86_64.tar.gz| gzip -d -c | tar xf - 
    mv ./kubens /usr/local/bin > /dev/null 2>&1
    curl -s -L https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx_v0.9.4_linux_x86_64.tar.gz | gzip -d -c | tar xf -
    mv ./kubectx /usr/local/bin > /dev/null  2>&1
    
    # install kustomize
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash > /dev/null  2>&1
    mv ./kustomize /usr/local/bin > /dev/null 2>&1
}

# function add_helm_repos {  
#     printf "==> add the helm repos required to support many kubernetes apps  \n" 
#     su - $k8s_user -c "helm repo add kiwigrid https://kiwigrid.github.io" > /dev/null 2>&1
#     su - $k8s_user -c "helm repo add kokuwa https://kokuwaio.github.io/helm-charts" > /dev/null 2>&1  #fluentd 
#     su - $k8s_user -c "helm repo add elastic https://helm.elastic.co" > /dev/null 2>&1
#     su - $k8s_user -c "helm repo add codecentric https://codecentric.github.io/helm-charts" > /dev/null 2>&1 # keycloak for TTK
#     su - $k8s_user -c "helm repo add bitnami https://charts.bitnami.com/bitnami" > /dev/null 2>&1
#     su - $k8s_user -c "helm repo add mojaloop http://mojaloop.io/helm/repo/" > /dev/null 2>&1
#     su - $k8s_user -c "helm repo add cowboysysop https://cowboysysop.github.io/charts/" > /dev/null 2>&1  # mongo-express
#     su - $k8s_user -c "helm repo add redpanda-data https://charts.redpanda.com/ " > /dev/null 2>&1   # kafka console 
#     su - $k8s_user -c "helm repo update" > /dev/null 2>&1
# }

function configure_k8s_user_env { 
    start_message="#K8S_START of config added by k8s-install.sh #"
#    grep "start of config added by k8s install  $k8s_user_home/.bashrc >/dev/null 2>&1
    if [[ $? -ne 0  ]]; then 
        printf "==> Adding configuration for %s to %s .bashrc\n" "$k8s_distro" "$k8s_user"
        printf "%s\n" "$start_message" >> $k8s_user_home/.bashrc 
        echo "source <(kubectl completion bash)" >> $k8s_user_home/.bashrc # add autocomplete permanently to your bash shell.
        echo "alias k=kubectl " >>  $k8s_user_home/.bashrc
        echo "complete -F __start_kubectl k " >>  $k8s_user_home/.bashrc
        echo "alias ksetns=\"kubectl config set-context --current --namespace\" " >>  $k8s_user_home/.bashrc
        echo "alias ksetuser=\"kubectl config set-context --current --user\" "  >>  $k8s_user_home/.bashrc
#        printf "#K8S__END end of config added by k8s-install.sh # \n" >> $k8s_user_home/.bashrc 
    else 
        printf "==> Configuration for .bashrc for %s for user %s already exists ..skipping\n" "$k8s_distro" "$k8s_user"
    fi
}

function verify_user {
# ensure that the user for k8s exists
        if [ -z ${k8s_user+x} ]; then 
            printf "** Error: The operating system user has not been specified with the -u flag \n" 
            printf "          the user specified with the -u flag must exist and not be the root user \n" 
            printf "** \n"
            exit 1
        fi

        if [[ `id -u $k8s_user >/dev/null 2>&1` == 0 ]]; then 
            printf "** Error: The user specified by -u should be a non-root user ** \n"
            exit 1
        fi 

        if id -u "$k8s_user" >/dev/null 2>&1 ; then
            k8s_user_home=`eval echo "~$k8s_user"`
            return
        else
            printf "** Error: The user [ %s ] does not exist in the operating system \n" $k8s_user
            printf "            please try again and specify an existing user \n"
            printf "** \n"
            exit 1 
        fi    
}

function delete_k8s {
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        printf "==> removing any existing Microk8s installation "
        snap remove microk8s > /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ microk8s delete failed ] \n"
            printf "** was microk8s installed ?? \n" 
            printf "   if so please try running \"sudo snap remove microk8s\" manually ** \n"
        fi
    else 
        printf "==> removing any existing k3s installation and helm binary"
        rm -f /usr/local/bin/helm >> /dev/null 2>&1
        /usr/local/bin/k3s-uninstall.sh >> /dev/null 2>&1
        if [[ $? -eq 0  ]]; then 
            printf " [ ok ] \n"
        else 
            printf " [ k3s delete failed ] \n"
            printf "** was k3s installed ?? \n" 
            printf "   if so please try running \"/usr/local/bin/k3s-uninstall.sh\" manually ** \n"
        fi
    fi    
    # remove config from user .bashrc
    perl -i -ne 'print unless /START_ML/ .. /END_ML/'  $k8s_user_home/.bashrc
}

function check_k8s_installed { 
    printf "==> Check the cluster is available and ready from kubectl  "
    k8s_ready=`su - $k8s_user -c "kubectl get nodes" | perl -ne 'print  if s/^.*Ready.*$/Ready/'`
    if [[ ! "$k8s_ready" == "Ready" ]]; then 
        printf "** Error : kubernetes is not installed , please run $0 -m install -u $k8s_user \n"
        printf "           before proceeding ...  \n "
        exit 1 
    fi
    printf "    [ ok ] \n"
}

function print_end_message { 
    printf "\n\n*********************** << success >> *******************************************\n"
    printf "            -- kubernetes install utility -- \n"
    printf "************************** << end  >> *******************************************\n\n"
} 

################################################################################
# Function: showUsage
################################################################################
# Description:		Display usage message
# Arguments:		none
# Return values:	none
#
function showUsage {
	if [ $# -ne 0 ] ; then
		echo "Incorrect number of arguments passed to function $0"
		exit 1
	else
echo  "USAGE: $0 -m [mode] -u [user] -v [k8 version] -k [distro] 
Example 1 : k8s-install-current.sh -m install -v 1.28 -k k3s # install k8s k3s version 1.28
Example 2 : k8s-install-current.sh -m delete  -v 1.27 -k k3s # delete  k8s microk8s version 1.27
Example 3 : k8s-install-current.sh -m install -k microk8s -v 1.26 # install k8s microk8s distro version 1.26

Options:
-m mode ............... install|delete (-m is required)
-u user ............... non root user to install k3s as (required) 
-k kubernetes distro... microk8s|k3s (default=k3s as it installs across multiple linux distros)
-v k8s version ........ 1.27|1.28 i.e. 2 latest k8s releases tested 
-h|H .................. display this message
"
	fi
}

################################################################################
# MAIN
################################################################################

BASE_DIR=$( cd $(dirname "$0")/../.. ; pwd )
RUN_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # the directory that this script is run from 

TD_KUBE_UTILS_BASE_DIR="$( cd $(dirname "$SCRIPTS_DIR")/.. ; pwd )"
echo "TD_KUBE_UTILS_BASE_DIR=$TD_KUBE_UTILS_BASE_DIR"
SCRIPTS_DIR="$TD_KUBE_UTILS_BASE_DIR/shared/scripts"
echo "SCRIPTS_DIR=$SCRIPTS_DIR"

DEFAULT_K8S_DISTRO="k3s"   # default to k3s 
K8S_VERSION="" 
HELM_VERSION="3.12.0"  # Feb 2023 
K8S_CURRENT_RELEASE_LIST=( "1.27" "1.28" )
CURRENT_RELEASE="false"
k8s_user_home=""
#k8s_arch=`uname -p`  # what arch
k8s_arch=`arch`  # what arch
# Set the minimum amount of RAM in GB
MIN_RAM=4
MIN_FREE_SPACE=30
LINUX_VERSION=""
LINUX_OS_LIST=( "Ubuntu" )
UBUNTU_OK_VERSIONS_LIST=( "22" ) 
os_dict["Ubuntu "]=(
    ["Ubuntu"]="22.04"
    ["Darwin"]="13.5"
)

CURRENT_OS=""
CURRENT_VERSION=""

# ensure we are running as root 
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

# Check arguments
if [ $# -lt 1 ] ; then
	showUsage
	echo "Not enough arguments -m mode must be specified "
	exit 1
fi

# Process command line options as required
while getopts "m:k:v:u:hH" OPTION ; do
   case "${OPTION}" in
        m)	    mode="${OPTARG}"
        ;;
        k)      k8s_distro="${OPTARG}"
        ;;
        v)	    k8s_user_version="${OPTARG}"
        ;;
        u)      k8s_user="${OPTARG}"
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

printf "\n\n*********************************************************************************\n"
printf "            -- kubernetes install utility -- \n"
printf "************************* << start >> *******************************************\n\n"

check_os  "$os_dict"
check_system_resources $CURRENT_OS $MIN_RAM $MIN_FREE_SPACE
check_arch_ok 
#set_user
verify_user

if [[ "$mode" == "install" ]]  ; then
    #check_resources_ok
    set_k8s_distro
    set_k8s_version
    k8s_already_installed
    check_pi  # note microk8s on my pi still has some issues around cgroups 
    #check_os_ok # todo add check to this once tested across other OS's more fully 
    install_prerequisites 
    #add_hosts
    if [[ "$k8s_distro" == "microk8s" ]]; then 
        printf "** WIP: Microk8s is not yet sufficiently tested \n"
        printf "        for example microk8s v1.28 install on Ubuntu 22.04 ARM64 seemed to have some issues \n"
        printf "        => please select k3s for now   *** \n"
        exit 1 
        #do_microk8s_install
    else 
        do_k3s_install
    fi 
    install_k8s_tools
    add_helm_repos 
    configure_k8s_user_env
    check_k8s_installed
    printf "==> kubernetes distro:[%s] version:[%s] is now configured for user [%s] and ready for further kube apps deployment \n" \
                "$k8s_distro" "$K8S_VERSION" "$k8s_user"
    print_end_message 
elif [[ "$mode" == "delete" ]]  ; then
    delete_k8s 
    print_end_message 
else 
    showUsage
fi 



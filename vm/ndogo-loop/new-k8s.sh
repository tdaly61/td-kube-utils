#!/usr/bin/env bash
# k8s.sh: Install Kubernetes k3s on Ubuntu OS
# Author: Tom Daly
# Date: April 2024

function check_pi {
    # This is to enable experimentation on Raspberry Pi which is WIP
    if [ -f "/proc/device-tree/model" ]; then
        model=$(cat /proc/device-tree/model | cut -d " " -f 3)
        printf "** Warning: Hardware is Raspberry Pi model: [%s] \n" "$model"
        printf " for Ubuntu 20 need to append cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 to /boot/cmdline.txt \n"
        printf " and reboot the Pi ** \n"
    fi
}

function check_arch_ok {
    if [[ "$k8s_arch" == "aarch64" ]]; then
        k8s_arch="arm64"
    fi
    if [[ ! "$k8s_arch" == "x86_64" ]] && [[ ! "$k8s_arch" == "arm64" ]]; then
        printf "** Error: Unrecognised architecture [%s] \n" "$k8s_arch"
        printf "   ndogo-loop deployment of vNext only works on x86_64 or arm64\n"
        exit
    fi
}

function check_resources_ok {
    # Get the total amount of installed RAM in GB
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    # Get the current free space on the root filesystem in GB
    free_space=$(df -BG /home/"$k8s_user" | awk '{print $4}' | tail -n 1 | sed 's/G//')

    # Check RAM
    if [[ "$total_ram" -lt "$MIN_RAM" ]]; then
        printf " ** Error: ndogo-loop currently requires $MIN_RAM GBs to run properly \n"
        printf "    Please increase RAM available before trying to run ndogo-loop \n"
        exit 1
    fi
    # Check free space
    if [[ "$free_space" -lt "$MIN_FREE_SPACE" ]]; then
        printf " ** Warning: ndogo-loop currently requires %sGBs free storage in %s home directory  \n" "$MIN_FREE_SPACE" "$k8s_user"
        printf "    but only found %sGBs free storage \n" "$free_space"
        printf "    ndogo-loop installation will continue, but beware it might fail later due to insufficient storage \n"
    fi
}

function set_user {
    # Set the k8s_user
    k8s_user=$(who am i | cut -d " " -f1)
}

function k8s_already_installed {
    if [[ -f "/usr/local/bin/k3s" ]]; then
        printf "** Error: k3s is already installed, please delete before reinstalling Kubernetes  **\n"
        exit 1
    fi
}

function set_linux_os_distro {
    if [ -r "/etc/os-release" ]; then
        . /etc/os-release
        LINUX_OS="$NAME"
        LINUX_VERSION="$VERSION_ID"
    else
        LINUX_OS="Unknown"
        LINUX_VERSION="Unknown"
    fi

    printf "==> Linux OS is [%s] version [ %s ]\n" "$LINUX_OS" "$LINUX_VERSION"
}

# function set_linux_os_distro {
#     if [ -x "/usr/bin/lsb_release" ]; then
#         LINUX_OS=$(lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/')
#         LINUX_VERSION=$(/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/')
#     else
#         LINUX_OS="Untested"
#     fi
#     printf "==> Linux OS is [%s] version [ %s ] " "$LINUX_OS" "$LINUX_VERSION"

# }

function check_os_ok {
    printf "==> Checking OS and Kubernetes distro is tested with ndogo-loop scripts\n"
    set_linux_os_distro
    if [[ ! $LINUX_OS == "Ubuntu" ]]; then
        printf "** Error, ndogo-loop $MINILOOP_VERSION is only tested with Ubuntu OS at this time   **\n"
        exit 1
    fi
    local os_version_ok=false
    for i in "${UBUNTU_OK_VERSIONS_LIST[@]}"; do
        if [[ "$LINUX_VERSION" == "$i" ]]; then
            os_version_ok=true
            break
        fi
    done
    if [[ ! "$os_version_ok" == true ]]; then
        printf "** Error, ndogo-loop $MINILOOP_VERSION is not tested with Ubuntu OS version [ %s ] at this time \n" "$LINUX_VERSION"
        printf "           current tested Ubuntu versions are :-  "
        printf " [ %s ] " "${UBUNTU_OK_VERSIONS_LIST[@]}"
        printf "   **\n"
        exit 1
    fi
}

function install_prerequisites {
    printf "==> Install any OS prerequisites, tools & updates  ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then
        printf "    apt update \n"
        apt update > /dev/null 2>&1
        printf "    python and python libs ...\n"
        apt install python3-pip -y > /dev/null 2>&1
        apt install python3.10-venv -y > /dev/null 2>&1
        su - "$k8s_user" -c "pip3 install --user virtualenv"
        su - "$k8s_user" -c "python3 -m venv $k8s_user_home/mlenv"
        su - "$k8s_user" -c "source $k8s_user_home/mlenv/bin/activate; pip3 install ruamel.yaml "
    fi
}

function add_hosts {
    printf "==> Mojaloop vNext k8s install: Update hosts file\n"
    ENDPOINTSLIST=(
        127.0.0.1
        mongohost.local mongoexpress.local vnextadmin.local elasticsearch.local kafkaconsole.local fspiop.local
        bluebank.local greenbank.local
    )

    export ENDPOINTS=$(echo "${ENDPOINTSLIST[*]}")

    perl -p -i.bak -e 's/127.0.1.1.*ubuntu.*/127.0.1.1  ubuntu  \n$ENV{ENDPOINTS}/' /etc/hosts
    printf "    Resultant /etc/hosts file updated as follows: \n"
    printf "    -------------------------------------------\n"
    cat /etc/hosts
    printf "    -------------------------------------------\n"
}

function install_k8s_tools {
    printf "==> Install additional Kubernetes tools ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then
        printf "    apt install kubectl ...\n"
        apt install -y kubectl > /dev/null 2>&1
        printf "    Install k9s \n"
        su - "$k8s_user" -c "curl -sS https://webinstall.dev/k9s | bash"
        su - "$k8s_user" -c "echo 'export PATH=\"$k8s_user_home/.local/bin/:$PATH\"' >> $k8s_user_home/.bashrc"
    fi
}

function add_helm_repos {
    printf "==> Adding Helm repos ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then
        printf "    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable \n"
        helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
        printf "    helm repo update \n"
        helm repo update > /dev/null 2>&1
    fi
}

function configure_k8s_user_env {
    printf "==> Configuring user environment ...\n"
    if [[ $LINUX_OS == "Ubuntu" ]]; then
        printf "    Enable Docker to start on boot ...\n"
        systemctl enable docker.service
        printf "    User $k8s_user added to docker group \n"
        usermod -aG docker "$k8s_user"
        printf "    User $k8s_user added to microk8s group \n"
        usermod -aG microk8s "$k8s_user"
    fi
    printf "==>  ndogo-loop $MINILOOP_VERSION installed, k3s configured and started \n"
}

function delete_k8s_distro {
    printf "==> Deleting Kubernetes k3s distribution ...\n"
    if [[ -f "/usr/local/bin/k3s-uninstall.sh" ]]; then
        /usr/local/bin/k3s-uninstall.sh > /dev/null 2>&1
    fi
}

function print_usage {
    printf "Usage: $0 [-i|-d] [-a <arch>] [-v <version>] \n"
    printf "  -i : Install Kubernetes k3s\n"
    printf "  -d : Delete Kubernetes k3s\n"
    printf "  -a : Architecture (default: x86_64)\n"
    printf "  -v : Kubernetes version (default: latest)\n"
    exit 1
}

# Main

# Set default values
k8s_arch="x86_64"
k8s_version="latest"
MIN_RAM=16
MIN_FREE_SPACE=30
UBUNTU_OK_VERSIONS_LIST=(20.04)

# Parse command-line arguments
while getopts "ida:v:" opt; do
    case $opt in
        i)
            install=true
            ;;
        d)
            delete=true
            ;;
        a)
            k8s_arch=$OPTARG
            ;;
        v)
            k8s_version=$OPTARG
            ;;
        \?)
            print_usage
            ;;
    esac
done

# Check for valid architecture
check_arch_ok

# Check if the user has permission to run the script
if [[ $EUID -ne 0 ]]; then
    printf "** Error: This script must be run as root\n"
    exit 1
fi

# Check if k3s is already installed
if [[ "$install" == true ]]; then
    k8s_already_installed
fi

# Check if the script is running on Raspberry Pi
check_pi

# Check if the OS is supported
check_os_ok

# Set the user for installation
set_user

# Check if resources are sufficient
check_resources_ok

# Install or delete Kubernetes k3s
if [[ "$install" == true ]]; then
    printf "==> Installing Kubernetes k3s...\n"
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --no-deploy traefik" sh -s - --disable servicelb --disable traefik --arch "$k8s_arch" --version "$k8s_version"
    install_prerequisites
    add_hosts
    install_k8s_tools
    add_helm_repos
    configure_k8s_user_env
elif [[ "$delete" == true ]]; then
    delete_k8s_distro
    printf "==> Kubernetes k3s distribution deleted\n"
else
    print_usage
fi

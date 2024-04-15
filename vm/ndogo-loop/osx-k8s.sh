#!/usr/bin/env bash
# k8s.sh : install kubernetes k3s or microk8s on local (Ubuntu) or macOS OS
# Author: Tom Daly
# Date: April 2024

function check_pi {
    # this is to enable experimentation on raspberry PI which is WIP
    if [ -f "/proc/device-tree/model" ]; then
        model=$(cat /proc/device-tree/model | cut -d " " -f 3)
        printf "** Warning : hardware is Raspberry PI model : [%s] \n" "$model"
        printf " for Ubuntu 20 need to append  cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 to /boot/cmdline.txt \n"
        printf " and reboot the PI ** \n"
    fi
}

function check_arch_ok {
    if [[ "$k8s_arch" == "aarch64" ]]; then
        k8s_arch="arm64"
    fi
    if [[ ! "$k8s_arch" == "x86_64" ]] && [[ ! "$k8s_arch" == "arm64" ]]; then
        printf "** Error: unrecognised architecture [%s] \n" "$k8s_arch"
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
        printf " ** Error : ndogo-loop currently requires $MIN_RAM GBs to run properly \n"
        printf "    Please increase RAM available before trying to run ndogo-loop \n"
        exit 1
    fi
    # Check free space
    if [[ "$free_space" -lt "$MIN_FREE_SPACE" ]]; then
        printf " ** Warning : ndogo-loop currently requires %sGBs free storage in %s home directory  \n" "$MIN_FREE_SPACE" "$k8s_user"
        printf "    but only found %sGBs free storage \n" "$free_space"
        printf "    ndogo-loop installation will continue , but beware it might fail later due to insufficient storage \n"
    fi
}

function set_user {
    # set the k8s_user
    k8s_user=$(who am i | cut -d " " -f1)
}

function k8s_already_installed {
    if [[ -f "/usr/local/bin/k3s" ]]; then
        printf "** Error , k3s is already installed , please delete before reinstalling kubernetes  **\n"
        exit 1
    fi
    # check to ensure microk8s isn't already installed when installing k3s
    if [[ -f "/snap/bin/microk8s" ]]; then
        printf "** Error , microk8s is already installed, please delete before reinstalling kubernetes  **\n"
        exit 1
    fi
}

function set_linux_os_distro {
    if [ -x "/usr/bin/lsb_release" ]; then
        LINUX_OS=$(lsb_release --d | perl -ne 'print  if s/^.*Ubuntu.*(\d+).(\d+).*$/Ubuntu/')
        LINUX_VERSION=$(/usr/bin/lsb_release --d | perl -ne 'print $&  if m/(\d+)/')
    else
        LINUX_OS="Untested"
    fi
    printf "==> Linux OS is [%s] version [ %s ] " "$LINUX_OS" "$LINUX_VERSION"
}

function check_os_ok {
    printf "==> checking OS and kubernetes distro is tested with ndogo-loop scripts\n"
    set_linux_os_distro
    if [[ ! $LINUX_OS == "Ubuntu" ]] && [[ ! $LINUX_OS == "Darwin" ]]; then
        printf "** Error , ndogo-loop $MINILOOP_VERSION is only tested with Ubuntu or macOS at this time   **\n"
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
        printf "** Error , ndogo-loop $MINILOOP_VERSION is not tested with Ubuntu version %s   **\n" "$LINUX_VERSION"
        printf "   tested versions are : "
        printf '%s ' "${UBUNTU_OK_VERSIONS_LIST[@]}"
        printf "\n"
        exit 1
    fi
}

function showUsage {
    printf "Usage: %s: \n" "$0"
    printf "   [-m MODE] - mode: [install|delete] default: install\n"
    printf "   [-k DISTRO] - kubernetes distro: [microk8s|k3s] default: k3s\n"
    printf "   [-v VERSION] - kubernetes version: default: latest\n"
    printf "   [-u USER] - username: default: current user\n"
    printf "   [-h] - Display this usage message\n"
}

# Default values
mode="install"
k8s_distro="k3s"
k8s_user_version="latest"
k8s_user=$(whoami)

# Process command line options as required
while getopts "m:k:v:u:hH" OPTION ; do
   case "${OPTION}" in
        m)      mode="${OPTARG}" ;;
        k)      k8s_distro="${OPTARG}" ;;
        v)      k8s_user_version="${OPTARG}" ;;
        u)      k8s_user="${OPTARG}" ;;
        h|H)    showUsage; exit 0 ;;
        *)      echo  "unknown option"; showUsage; exit 1 ;;
    esac
done

# Constants
MIN_RAM=8
MIN_FREE_SPACE=30
MINILOOP_VERSION="vNext"

# Main script
printf "==> Checking if this is Raspberry PI\n"
check_pi

printf "==> Setting username to current user [%s]\n" "$k8s_user"
set_user

printf "==> checking OS requirements\n"
check_os_ok

printf "==> Checking if k8s is already installed\n"
k8s_already_installed

printf "==> Checking if hardware and OS are supported\n"
check_arch_ok

printf "==> Checking system resources\n"
check_resources_ok

printf "==> Starting script action\n"
printf "    mode              : [%s] \n" "$mode"
printf "    k8s_distro        : [%s] \n" "$k8s_distro"
printf "    k8s_user_version  : [%s] \n" "$k8s_user_version"
printf "    k8s_user          : [%s] \n" "$k8s_user"

# Add the rest of the script functionality below
# (e.g., installation, deletion, etc.)

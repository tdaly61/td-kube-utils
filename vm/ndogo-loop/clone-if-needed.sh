#!/bin/bash 

clone_if_needed() {
    local repo_url="$1"
    local destination_dir="$2"

    # Check if the destination directory exists and is a git repository
    if [[ -d "$destination_dir/.git" ]]; then
        # Check if there are any changes in the repository
        if [[ -n $(git -C "$destination_dir" status --porcelain | grep "^??") ]]; then
            echo "Untracked files detected in $destination_dir. Recloning..."
            rm -rf "$destination_dir"
            git clone "$repo_url" "$destination_dir"
        else
            echo "No local changes detected in $destination_dir"
        fi
    else
        echo "$destination_dir does not exist or is not a git repository. Cloning..."
        git clone "$repo_url" "$destination_dir"
    fi
}

VNEXT_LOCAL_REPO_DIR="$HOME/tmp/platform-shared-tools" 
VNEXT_GITHUB_REPO="https://github.com/mojaloop/platform-shared-tools" 
clone_if_needed  $VNEXT_GITHUB_REPO $VNEXT_LOCAL_REPO_DIR


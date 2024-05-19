#!/bin/bash

# Function to handle dumping or restoring MongoDB data
mongo_data_action() {
  local action=$1
  local mongo_gzip_file=$2

  echo "Action: $action"
  echo "Mongo GZIP file: $mongo_gzip_file"

  error_message="${action}ing the mongo database data failed"
  trap 'handle_warning $LINENO "$error_message"' ERR

  printf "==> ${action}ing mongodb demonstration/test data and ttk configs\n"
  printf "   - ${action}ing mongodb data\n"

  mongopod=$(kubectl get pods --namespace "$NAMESPACE" | grep -i mongodb | awk '{print $1}')
  mongo_root_pw=$(kubectl get secret mongodb -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d)

  echo "MongoDB Pod: $mongopod"
  echo "MongoDB Root Password: $mongo_root_pw"

  if [ -z "$mongopod" ]; then
    echo "Error: Could not find MongoDB pod."
    exit 1
  fi

  if [ -z "$mongo_root_pw" ]; then
    echo "Error: Could not retrieve MongoDB root password."
    exit 1
  fi

  if [ "$action" == "dump" ]; then
    kubectl exec --stdin --tty "$mongopod" -- mongodump -u root -p "$mongo_root_pw" \
      --gzip --archive=/tmp/mongodump.gz --authenticationDatabase admin >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Error: mongodump command failed."
      exit 1
    fi

    # Copy the dump file from the pod to the specified directory
    kubectl cp "$mongopod:/tmp/mongodump.gz" "$mongo_gzip_file" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Error: Failed to copy mongodump.gz from MongoDB pod."
      exit 1
    fi

  elif [ "$action" == "restore" ]; then
    kubectl cp "$mongo_gzip_file" "$mongopod:/tmp/mongodump.gz" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Error: Failed to copy mongodump-beta.gz to MongoDB pod."
      exit 1
    fi

    kubectl exec --stdin --tty "$mongopod" -- mongorestore -u root -p "$mongo_root_pw" \
      --gzip --archive=/tmp/mongodump.gz --authenticationDatabase admin >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "Error: mongorestore command failed."
      exit 1
    fi
  else
    echo "Invalid action specified. Use 'dump' or 'restore'."
    return 1
  fi

  printf " [ ok ]\n"
}

# Function to handle warnings
handle_warning() {
  local lineno=$1
  local msg=$2
  echo "Warning: Error on or near line ${lineno}: ${msg}"
}

# Function to display usage
usage() {
  echo "Usage: $0 -a <dump|restore> -d <mongo_gzip_file> "
  exit 1
}

# Default namespace
NAMESPACE=${NAMESPACE:-default}

# Parse command-line arguments
while getopts ":a:d:" opt; do
  case ${opt} in
    a)
      action=$OPTARG
      ;;
    d)
      mongo_gzip_file=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "$action" || -z "$mongo_gzip_file" ]]; then
  usage
fi

# Call the function with the parsed arguments
mongo_data_action "$action" "$mongo_gzip_file"

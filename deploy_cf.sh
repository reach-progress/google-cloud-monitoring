#!/usr/bin/env bash

set -e

function usage() {
  echo "Usage:"
  echo ""
  echo "[p]     project ID"
  echo "[f]     function name"
  echo "[m]     service account email (member) to deploy as or invoke cloud function as"
  echo ""
  echo "Deploy a cloud function with a service account:

  ./deploy_cf.sh deploy -p PROJECT_ID -m CUSTOM_SA@PROJECT_ID.iam.gserviceaccount.com [-f FUNCTION_NAME]"
  echo ""
  echo "Load (or create a new) secret with the contents of a json file:

  cat secret.json | jq -c | ./deploy_cf.sh load [create] -i SECRET_ID -p PROJECT_ID"
}

if [[ -n "$1" && "$1" != "" ]]; then
  subcommand=$1
else
  usage
fi

case $1 in
  "$1")
    COMMAND=$subcommand; shift #remove subcommand

  while getopts "i:e:p:m:f:" opt; do
      case ${opt} in
          i)
              secret_id=$OPTARG
              ;;
          e)
              stage=$OPTARG
              ;;
          p)
              project_id=$OPTARG
              ;;
          m)
              member=$OPTARG
              ;;
          f)
              override_function_name=$OPTARG
              ;;
          *)
              usage
              ;;
      esac
  done
  shift $((OPTIND-1))
esac

function build() {

  echo -e "Installing dependencies..."
  if ! npm install; then echo "npm install failed" && exit 1; fi

  echo -e "Transpiling ts --> js and running functions-framework..."
  if ! npm start; then echo "Transpiling failed!" && exit 1; fi

}

function deploy() {
  # freeze requirements
  build

  default_function_name=$(basename "$PWD")
  functionname=${override_function_name:=$default_function_name}

  if [[ -n "$member" && "$member" != "" ]]; then
    echo -e "Deploying with custom service account ${member}..."

    gcloud functions deploy "$functionname" \
    --gen2 \
    --entry-point="SyntheticFunction" \
    --region="us-central1" \
    --project="$project_id" \
    --timeout="3600" \
    --runtime nodejs18 \
    --trigger-http \
    --allow-unauthenticated \
    --service-account="${member}" \
    --source .
  else
    echo -e "Deploying with default service account..."

    gcloud functions deploy "$functionname" \
    --gen2 \
    --entry-point="SyntheticFunction" \
    --region="us-central1" \
    --project="$project_id" \
    --timeout="3600" \
    --runtime nodejs18 \
    --trigger-http \
    --allow-unauthenticated \
    --source .
  fi
}

function create() {
  gcloud secrets create "$secret_id" \
      --replication-policy="user-managed" \
      --locations="us-central1" \
      --project="$project_id" \
      --data-file=-
}

function delete() {
  gcloud secrets delete "$secret_id" \
    --project="$project_id"
}

function load() {
  gcloud secrets versions add "$secret_id" \
    --project="$project_id" \
    --data-file=-
}

# Run the command function
"$COMMAND" "$@"

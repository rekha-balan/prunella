#!/bin/bash
. ./utils.sh

function display_help() {
	echo -e "\n${PROJECT_NAME} deployment utility v1.0\n"
	echo -e "usage: deploy.sh -/-- options:\n"
	echo -e "\t--help, -h"
	echo -e "\t  displays more detailed help\n"
	echo -e "\t--resource-group, -g <resource group>"
	echo -e "\t  the resource group to deploy to\n"
	echo -e "\t--location, -l <location> "
	echo -e "\t  the location to deploy to\n"
	echo -e "\t--service-principal-id, -u <service principal id>"
	echo -e "\t  the service principal id to use for deploying\n"
	echo -e "\t--service-principal-key, -p <service principal key>"
	echo -e "\t  the service principal key to use for deploying\n"
	echo -e "\t--prunella-services-id <prunella services id>"
	echo -e "\t  prunella services full id \n"
	echo -e "\t--prunella-status-topic-id <prunella status topic id>"
	echo -e "\t  prunella services full id \n"
	echo -e "\t--prunella-output <prunella output path>"
	echo -e "\t  prunella output full file \n"
	echo -e "\t--name-fix, -n <name fix>"
	echo -e "\t  post fix to use for naming different resources\n"
	echo -e "\t--name-fix-resource-group, -ng"
	echo -e "\t  apply same name fix to resource group\n"
	echo -e "\t--omit-jump-box, -ojb"
	echo -e "\t  don't deploy a jumpbox in resource group\n"
	echo -e "\t--verbose, -v"
	echo -e "\t  verbose mode outputting more details\n"
	echo -e "\t--development, -dev"
	echo -e "\t  development mode taking some shortcuts\n"
}

# set some defaults
BUILD_MODE="default"
PROJECT_NAME="haproxy"
OPERATION_MODE="default"
OMIT_JUMP_BOX="false"

# parse the argumens
while true; do
  case "$1" in
	-h | --help ) display_help; exit 1 ;;
    -l | --location ) LOCATION="$2"; shift ; shift ;;
    -g | --resource-group ) RESOURCE_GROUP="$2"; shift ; shift ;;
    -u | --service-principal-id ) SERVICE_PRINCIPAL_ID="$2"; shift ; shift ;;
    -p | --service-principal-key ) SERVICE_PRINCIPAL_KEY="$2"; shift ; shift ;;
    -n | --name-fix ) NAME_FIX="$2"; shift ; shift ;;
    -ng | --name-fix-resource-group ) NAME_FIX_RESOURCE_GROUP=true; shift ;;
    -ojb | --omit-jump-box ) OMIT_JUMP_BOX="true"; shift ;;
    -v | --verbose ) BUILD_MODE="verbose"; shift ; shift ;;
    -dev | --development ) OPERATION_MODE="development"; shift ;;
    --prunella-output ) PRUNELLA_OUTPUT="$2"; shift ; shift ;;
    --prunella-services-id ) PRUNELLA_SERVICES_ID="$2"; shift ; shift ;;
    --prunella-key-vault-id ) PRUNELLA_KEY_VAULT_ID="$2"; shift ; shift ;;
    --prunella-key-vault-uri ) PRUNELLA_KEY_VAULT_URI="$2"; shift ; shift ;;
    --prunella-status-topic-id ) PRUNELLA_STATUS_TOPIC_ID="$2"; shift ; shift ;;
    --prunella-storage-account-id ) PRUNELLA_STORAGE_ACCOUNT_ID="$2"; shift ; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# tools required to be able to work
require_tool az || exit 1
require_tool jq || exit 1

# override if needed
if [ -n "${PRUNELLA_OUTPUT+set}" ]; then
	PRUNELLA_SERVICES_ID=$(cat ${PRUNELLA_OUTPUT} | jq -r .properties.outputs.servicesId.value)
	PRUNELLA_KEY_VAULT_ID=$(cat ${PRUNELLA_OUTPUT} | jq -r .properties.outputs.keyVaultId.value)
	PRUNELLA_KEY_VAULT_URI=$(cat ${PRUNELLA_OUTPUT} | jq -r .properties.outputs.keyVaultUri.value)
	PRUNELLA_STATUS_TOPIC_ID=$(cat ${PRUNELLA_OUTPUT} | jq -r .properties.outputs.statusTopicId.value)
	PRUNELLA_STORAGE_ACCOUNT_ID=$(cat ${PRUNELLA_OUTPUT} | jq -r .properties.outputs.storageAccountId.value)
fi

# validation checking
if [ -z ${LOCATION+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --location, -l is missing.\n"
	echo -e "\tusage: --location, -l [westeurope, westus, northeurope, ...]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${RESOURCE_GROUP+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --resource-group, -g is missing.\n"
	echo -e "\tusage: --resource-group, -g [NAME]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-id, -u is missing.\n"
	echo -e "\tusage: --service-principal-id, -u [SERVICE PRINCIPAL ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${SERVICE_PRINCIPAL_KEY+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --service-principal-key, -p is missing.\n"
	echo -e "\tusage: --service-principal-key, -p [SERVICE PRINCIPAL KEY]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${PRUNELLA_SERVICES_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --prunella-services-id is missing.\n"
	echo -e "\tusage: --prunella-services-id, -p [PRUNELLA SERVICES ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${PRUNELLA_STATUS_TOPIC_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --prunella-status-topic-id is missing.\n"
	echo -e "\tusage: --prunella-status-topic-id, -p [PRUNELLA STATUS TOPIC ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${PRUNELLA_STORAGE_ACCOUNT_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --prunella-storage-account-id is missing.\n"
	echo -e "\tusage: --prunella-storage-account-id, -p [PRUNELLA STATUS TOPIC ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${PRUNELLA_KEY_VAULT_ID+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --prunella-key-vault-id is missing.\n"
	echo -e "\tusage: --prunella-key-vault-id, -p [PRUNELLA STATUS TOPIC ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -z ${PRUNELLA_KEY_VAULT_URI+x} ]
	then 
	display_help
	display_error "One or more missing or incorrect arguments\n"
	display_error "\terror: --prunella-key-vault-ur is missing.\n"
	echo -e "\tusage: --prunella-key-vault-uri, -p [PRUNELLA STATUS TOPIC ID]"
	echo -e "\n"
	exit 1; 
fi
if [ -n "${NAME_FIX+set}" ]; then
	UNIQUE_NAME_FIX=${NAME_FIX} 
else 
	UNIQUE_NAME_FIX="$(dd if=/dev/urandom bs=6 count=1 2>/dev/null | base64 | tr '[:upper:]+/=' '[:lower:]abc')"
fi
if [ -n "${NAME_FIX_RESOURCE_GROUP+set}" ]; then
	RESOURCE_GROUP=${RESOURCE_GROUP}-${UNIQUE_NAME_FIX} 		
fi

# generate unique ticks
UNIQUE_TICKS=$(($(date +%s%N)/1000))

# variables come here
OUTPUT_DIR="$(dirname "$PWD")"/output

# prepare target environment
rm -rf ${OUTPUT_DIR}
mkdir -p ${OUTPUT_DIR}/deploy
cp -r * ${OUTPUT_DIR}/deploy

mkdir -p ${OUTPUT_DIR}/scripts
# cp -r ../scripts/* ${OUTPUT_DIR}/scripts
pushd ../scripts
tar cf - --exclude=node_modules . | (cd ${OUTPUT_DIR}/scripts && tar xvf - )
popd

# pass the environment
cat <<-EOF > ${OUTPUT_DIR}/deploy/environment.sh
LOCATION=${LOCATION}
OUTPUT_DIR=${OUTPUT_DIR}
BUILD_MODE=${BUILD_MODE}
PROJECT_NAME=${PROJECT_NAME}
RESOURCE_GROUP=${RESOURCE_GROUP}
OPERATION_MODE=${OPERATION_MODE}
OMIT_JUMP_BOX=${OMIT_JUMP_BOX}
UNIQUE_TICKS=${UNIQUE_TICKS}
UNIQUE_NAME_FIX=${UNIQUE_NAME_FIX}
SERVICE_PRINCIPAL_ID=${SERVICE_PRINCIPAL_ID}
SERVICE_PRINCIPAL_KEY=${SERVICE_PRINCIPAL_KEY}
PRUNELLA_SERVICES_ID=${PRUNELLA_SERVICES_ID}
PRUNELLA_STATUS_TOPIC_ID=${PRUNELLA_STATUS_TOPIC_ID}
PRUNELLA_KEY_VAULT_ID=${PRUNELLA_KEY_VAULT_ID}
PRUNELLA_KEY_VAULT_URI=${PRUNELLA_KEY_VAULT_URI}
PRUNELLA_STORAGE_ACCOUNT_ID=${PRUNELLA_STORAGE_ACCOUNT_ID}
EOF

# all done change directory and let's boot
pushd ${OUTPUT_DIR}/deploy >/dev/null
${OUTPUT_DIR}/deploy/boot.sh
popd >/dev/null
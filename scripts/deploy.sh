#!/bin/bash

while getopts "st" option; do
   case $option in
      s) skipBuild=1;; # use '-s' cmdline flag to skip the container build step
	  t) testApi=1;; # use '-t' cmdline flag to skip the api tests
   esac
done

export LOCATION='westeurope'
API_NAME='aca-todolist-demo'
RG_NAME="$API_NAME-rg"
API_PORT='8080'
METRICS_PORT='8081'
SEMVER='0.1.1'
USER_PRINCIPAL_ID=`az ad signed-in-user show --query id --output tsv`
SUBSCRIPTION_ID=`az account show --query id -o tsv`

export METRICS_ENDPOINT="http://localhost:${METRICS_PORT}/metrics"
export RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RG_NAME}/providers/Microsoft.App/containerapps/${API_NAME}"

# create resource group
az group create --location $LOCATION --name $RG_NAME

if [[ $skipBuild != 1 ]]; then
	az deployment group create \
	--resource-group $RG_NAME \
	--name 'acr-deployment' \
	--parameters anonymousPullEnabled=true \
	--template-file ../infra/modules/acr.bicep
fi

# create storage account & fileshare to store 'telegraf.conf'
az deployment group create \
--resource-group $RG_NAME \
--name 'storage-deployment' \
--template-file ../infra/modules/stor.bicep \
--parameters location=$LOCATION \
--parameters fileShareName='telegraf-share'

STORAGE_ACCOUNT_NAME=`az deployment group show \
--resource-group $RG_NAME \
--name 'storage-deployment' \
--query properties.outputs.storageAccountName.value \
--output tsv`

SHARE_NAME=`az deployment group show \
--resource-group $RG_NAME \
--name 'storage-deployment' \
--query properties.outputs.shareName.value \
--output tsv`

STORAGE_ACCOUNT_KEY=`az deployment group show \
--resource-group $RG_NAME \
--name 'storage-deployment' \
--query properties.outputs.storageAccountKey.value \
--output tsv`

# substitute variables in telegraf.conf.template to new file 'telegraf.conf'
envsubst < telegraf.conf.template > telegraf.conf

# upload 'telegraph.conf' to Azure file share
az storage file upload \
--account-name $STORAGE_ACCOUNT_NAME \
--share-name $SHARE_NAME \
--account-key "$STORAGE_ACCOUNT_KEY" \
--source "./telegraf.conf" \
--path "telegraf.conf"

ACR_NAME=$(az deployment group show --resource-group $RG_NAME --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)
IMAGE="$ACR_NAME.azurecr.io/$API_NAME-api:v$SEMVER"

# build & push container image to ACR
if [[ $skipBuild != 1 ]]; then
	cd ..

	az acr login -n $ACR_NAME 
	echo "IMAGE NAME: '$IMAGE'"
	docker build -t $IMAGE -f ./Dockerfile .
	docker push $IMAGE

	cd ./scripts
fi

# deploy infrastructire & ACA app
az deployment group create \
--resource-group $RG_NAME \
--name 'app-deployment' \
--template-file ../infra/main.bicep \
--parameters location=$LOCATION \
--parameters apiName=$API_NAME \
--parameters apiPort=$API_PORT \
--parameters acrName=$ACR_NAME \
--parameters sqlAdminLoginName='dbadmin' \
--parameters containerImage=$IMAGE \
--parameters storageAccountName=$STORAGE_ACCOUNT_NAME \
--parameters fileShareName=$SHARE_NAME \
--parameters userPrincipalId=$USER_PRINCIPAL_ID

APP_FQDN=`az deployment group show \
--resource-group $RG_NAME \
--name 'app-deployment' \
--query properties.outputs.fqdn.value \
--output tsv`

echo "APP_FQDN: $APP_FQDN"

SQL_ADMIN_PASSWORD=`az deployment group show \
--resource-group $RG_NAME \
--name 'app-deployment' \
--query properties.outputs.sqlAdminLoginPassword.value \
--output tsv`

echo "SQL_ADMIN_PASSWORD: $SQL_ADMIN_PASSWORD"

if [[ $testApi == 1 ]]; then

	# add todos
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some dog food"}'
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some eggs"}'
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some onions"}'
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some milk"}'
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some bread"}'
	curl "https://$APP_FQDN/api/todos" -X POST -d '{"description": "get some cat food"}'

	# list all todos
	curl "https://$APP_FQDN/api/todos" | jq

	# complete a todo
	curl "https://$APP_FQDN/api/todos/complete/1" -X PATCH

	# list all completed todos
	curl "https://$APP_FQDN/api/todos/completed" | jq

	# list all incomplete todos
	curl "https://$APP_FQDN/api/todos/incomplete" | jq

	# delete a todo
	curl "https://$APP_FQDN/api/todos/1" -X DELETE | jq
fi

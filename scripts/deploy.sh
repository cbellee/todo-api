#!/bin/bash

while getopts ":s" option; do
   case $option in
      s) skipBuild=1; # use '-s' cmdline flag to skip the container build step
   esac
done

LOCATION='australiaeast'
API_NAME='todolist'
RG_NAME="$API_NAME-api-rg"
SEMVER='0.1.0'
REV=$(git rev-parse --short HEAD)
TAG="$SEMVER-$REV"
API_IMAGE="$API_NAME-api:$TAG"
API_PORT='8080'

source ../.env

az group create --location $LOCATION --name $RG_NAME

if [[ $skipBuild != 1 ]]; then
	az deployment group create \
		--resource-group $RG_NAME \
		--name 'acr-deployment' \
		--parameters anonymousPullEnabled=true \
		--template-file ../infra/modules/acr.bicep
fi

ACR_NAME=$(az deployment group show --resource-group $RG_NAME --name 'acr-deployment' --query properties.outputs.acrName.value -o tsv)
IMAGE_NAME="$ACR_NAME.azurecr.io/$API_IMAGE"

if [[ $skipBuild != 1 ]]; then
	cd ..
	echo "IMAGE NAME: '$IMAGE_NAME'"

	az acr login -n $ACR_NAME 
	docker build -t $IMAGE_NAME \
	-f ./Dockerfile .

	docker push $IMAGE_NAME

	cd ./scripts
fi

az deployment group create \
--resource-group $RG_NAME \
--name 'infra-deployment' \
--template-file ../infra/main.bicep \
--parameters location=$LOCATION \
--parameters apiName=$API_NAME \
--parameters apiPort=$API_PORT \
--parameters acrName=$ACR_NAME \
--parameters sqlAdminLoginName='dbadmin' \
--parameters sqlAdminPassword=$SQL_ADMIN_PASSWORD \
--parameters containerImage=$IMAGE_NAME

APP_FQDN=`az deployment group show \
--resource-group $RG_NAME \
--name 'infra-deployment' \
--query properties.outputs.fqdn.value \
--output tsv`

curl "https://$APP_FQDN/api/todos"
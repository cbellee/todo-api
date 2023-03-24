# az extension add --name containerapp --upgrade
# az provider register --namespace Microsoft.App
# az provider register --namespace Microsoft.OperationalInsights

RESOURCE_GROUP='aca-todo-api-rg'
LOCATION='australiaeast'
ACA_ENVIRONMENT='aca-todo-env'
REGISTRY='acatodocbellee'
IDENTITY='aca-todo-id'
CONTAINER_APP_NAME='todo-api'
WORKSPACE_NAME='aca-todo-api-wks'
REVISION_ID=`git rev-parse --short HEAD`

az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

WORKSPACE_ID=`az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --name $WORKSPACE_NAME \
  --sku PerGB2018 \
  --query customerId \
  --output tsv`

WORKSPACE_KEY=`az monitor log-analytics workspace get-shared-keys \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $WORKSPACE_NAME \
  --query primarySharedKey \
  --output tsv`

az identity create \
  --name $IDENTITY \
  --resource-group $RESOURCE_GROUP

IDENTITY_ID=`az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY \
  --query id \
  --output tsv`

PRINCIPAL_ID=`az identity show \
  --resource-group $RESOURCE_GROUP \
  --name $IDENTITY \
  --query principalId \
  --output tsv`

REGISTRY_ID=`az acr create \
 --name $REGISTRY \
 --resource-group $RESOURCE_GROUP \
 --sku Standard \
 --query id \
 --output tsv`

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --scope $REGISTRY_ID \
  --role acrpull

az containerapp env create \
  --name $ACA_ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --logs-workspace-id $WORKSPACE_ID \
  --logs-workspace-key $WORKSPACE_KEY

# build and push container app
IMAGE_NAME_TAG="$REGISTRY.azurecr.io/api:$REVISION_ID"
az acr build -t $IMAGE_NAME_TAG --registry $REGISTRY .

APP_FQDN=`az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $ACA_ENVIRONMENT \
  --image $IMAGE_NAME_TAG \
  --target-port 8080 \
  --ingress 'external' \
  --user-assigned $IDENTITY_ID \
  --registry-identity $IDENTITY_ID \
  --registry-server "$REGISTRY.azurecr.io" \
  --query properties.configuration.ingress.fqdn \
  --output tsv`

# list todos
curl https://$APP_FQDN/api/todos

# add todos
curl https://$APP_FQDN/api/todos -X POST -d '{"description":"get some milk"}'
curl https://$APP_FQDN/api/todos -X POST -d '{"description":"get some bread"}'
curl https://$APP_FQDN/api/todos -X POST -d '{"description":"get some cheese"}'
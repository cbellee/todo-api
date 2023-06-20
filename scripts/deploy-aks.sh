version='0.1.7'
acrName='acr2b97'
rgName='aks-agic-mtls-4-rg'
dnsRgName='external-dns-zones-rg'
zoneName='kainiindustries.net'
apiName='todo-api'
uiName='todo'
backendApiUrl="http://${apiName}.kainiindustries.net"
frontendApiUrl="http://${uiName}.kainiindustries.net"
backendImageTag="${acrName}.azurecr.io/todo-api-backend:${version}"
frontendImageTag="${acrName}.azurecr.io/todo-api-frontend:${version}"

# build & push images
echo "building & pushing images..."

cd ../api
docker build -t $backendImageTag .

cd ../ui
docker build -t $frontendImageTag .

az acr login --name acr2b97
docker push $backendImageTag
docker push $frontendImageTag

cd ..

# replace & apply backend manifest to cluster
echo "substituting backend manifest..."
sed "s|<IMAGE_TAG>|${backendImageTag}|g;" ./manifests/todo-api-backend.yaml | kubectl apply -f -

# get backend service LoadBalancer IP
BACKEND_SVC_IP=$(kubectl get svc todo-api-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# set DNS entry for backend API
echo "adding Public DNS record for backend..."
az network dns record-set a add-record -g $dnsRgName -z $zoneName -n $apiName -a $BACKEND_SVC_IP

# replace & apply frontend manifest to cluster
echo "substituting frontend manifest..."
sed "s|<API_URL>|${backendApiUrl}|g;s|<IMAGE_TAG>|${frontendImageTag}|g;" ./manifests/todo-api-frontend.yaml | kubectl apply -f -

# set DNS entry for frontend API
echo "adding Public DNS record for frontend..."
FRONTEND_SVC_IP=$(kubectl get svc todo-react-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
az network dns record-set a add-record -g $dnsRgName -z $zoneName -n $uiName -a $FRONTEND_SVC_IP

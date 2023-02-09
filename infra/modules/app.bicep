param location string
param apiName string
param tags object
param apiPort string
param containerImage string
param acrName string
param managedEnvironmentId string
param storageAccountKey string
param telegrafImage string = 'telegraf:1.23.4'
param telegrafApiPort string = '8086'
param acrLoginServer string
param acrAdminPassword string
param sqlCxnString string
param storageNameMount string
param volumeName string
param mountPath string

/* resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'todolist-msi'
  location: location
}
 */
resource todoListApi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: apiName
  location: location
  tags: tags
  /*   identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  } */
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Single'
      secrets: [
        {
          name: 'registry-password'
          value: acrAdminPassword
        }
        {
          name: 'sql-cxn-string'
          value: sqlCxnString
        }
        {
          name: 'storage-account-key'
          value: storageAccountKey
        }
      ]
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: acrLoginServer
          username: acrName
        }
      ]
      ingress: {
        external: true
        targetPort: int(apiPort)
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'http'
      }
    }
    managedEnvironmentId: managedEnvironmentId
    template: {
      volumes: [
        {
          name: volumeName
          storageType: 'AzureFile'
          storageName: storageNameMount
        }
      ]
      containers: [
        {
          image: containerImage
          name: apiName
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          probes: [
            {
              type: 'Readiness'
              initialDelaySeconds: 15
              failureThreshold: 3
              periodSeconds: 15
              httpGet: {
                port: int(apiPort)
                path: '/api/healthz/readiness'
              }
            }
            {
              type: 'Liveness'
              initialDelaySeconds: 15
              failureThreshold: 3
              periodSeconds: 15
              httpGet: {
                port: int(apiPort)
                path: '/api/healthz/liveness'
              }
            }
          ]
          env: [
            {
              name: 'DSN'
              secretRef: 'sql-cxn-string'
            }
          ]
        }
        {
          image: telegrafImage
          name: 'telegraf'
          resources: {
            cpu: '0.25'
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              mountPath: mountPath
              volumeName: volumeName
            }
          ]
          env: [
            {
              name: 'RESOURCE_ID'
              value: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.App/containerapps/${apiName}'
            }
            {
              name: 'LOCATION'
              value: location
            }
            {
              name: 'INSTANCE'
              value: apiName
            }
            {
              name: 'PROMETHEUS_URL'
              value: 'http://localhost:8080/api/metrics'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
        ]
      }
    }
  }
}

output ipAddress string = todoListApi.properties.outboundIpAddresses[0]
output fqdn string = todoListApi.properties.configuration.ingress.fqdn

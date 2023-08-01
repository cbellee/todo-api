param location string
param apiName string
param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}
param apiPort string
param containerImage string
param acrName string
param managedEnvironmentId string
param storageAccountName string
param telegrafImage string = 'telegraf:1.23.4'
param sqlCxnString string
param storageNameMount string = 'storage-mount'
param volumeName string = 'storage-volume'
param mountPath string = '/mnt/storage'
param userPrincipalId string
param concurrentRequestsScaleRule string = '50'
param listenAddress string = '8080'
param metricsListenAddress string = '8081'
param maxIdleDbCxns string = '10'
param maxOpenDbCxns string = '20'
param timeStamp string = utcNow()
param minReplicas int = 3
param maxReplicas int = 12

var azMonMetricsPublisherRoleDefinitionID = '3913510d-42f4-4e42-8a64-420c390055eb'
var azMonDataReaderRoleDefinitionID = 'b0d8363b-8ddd-447d-831f-62ca05bff136'
var grafanaAdminRoleDefinitionID = '22926164-76b3-42b3-bc55-97df8dab3e41'
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var umidName = 'aca-umid'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource umid 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: umidName
  location: location
}

module acrPull 'rbac-resource-scope.bicep' = {
  name: 'module-acrPull-${timeStamp}'
  params: {
    acrName: acrName
    umidName: umidName
    acrPullRoleDefinitionId: acrPullRoleDefinitionId
  }
}

resource todoListApi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: apiName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${umid.id}': {}
    }
  }
  properties: {
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: [
        {
          name: 'sql-cxn-string'
          value: sqlCxnString
        }
        {
          name: 'storage-account-key'
          value: storageAccount.listKeys().keys[0].value
        }
      ]
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: umid.id
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
                path: '/healthz/readiness'
              }
            }
            {
              type: 'Liveness'
              initialDelaySeconds: 15
              failureThreshold: 3
              periodSeconds: 15
              httpGet: {
                port: int(apiPort)
                path: '/healthz/liveness'
              }
            }
          ]
          env: [
            {
              name: 'DB_CXN'
              secretRef: 'sql-cxn-string'
            }
            {
              name: 'LISTEN_ADDR'
              value: listenAddress
            }
            {
              name: 'METRICS_LISTEN_ADDR'
              value: metricsListenAddress
            }
            {
              name: 'MAX_IDLE_DB_CXNS'
              value: maxIdleDbCxns
            }
            {
              name: 'MAX_OPEN_DB_CXNS'
              value: maxOpenDbCxns
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
          env: []
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: concurrentRequestsScaleRule
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    acrPull
  ]
}

module azMonMetricsPublisherRbac 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-azMonMetricsPublisherRbac-${timeStamp}'
  params: {
    principalId: umid.properties.principalId
    roleDefinitionID: azMonMetricsPublisherRoleDefinitionID
    principalType: 'ServicePrincipal'
  }
}

module azMonDataReader 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-azMonDataReaderRbac-${timeStamp}'
  params: {
    principalId: userPrincipalId
    roleDefinitionID: azMonDataReaderRoleDefinitionID
    principalType: 'User'
  }
}

module grafanaAdminRole 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-grafanaAdminRbac-${timeStamp}'
  params: {
    principalId: userPrincipalId
    roleDefinitionID: grafanaAdminRoleDefinitionID
    principalType: 'User'
  }
}

module grafanaReadAccessLogAnalyticsRole 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-grafanaLogAnalyticsReadRbac-${timeStamp}'
  params: {
    principalId: userPrincipalId
    roleDefinitionID: grafanaAdminRoleDefinitionID
    principalType: 'ServicePrincipal'
  }
}

output ipAddress string = todoListApi.properties.outboundIpAddresses[0]
output fqdn string = todoListApi.properties.configuration.ingress.fqdn

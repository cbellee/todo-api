param location string
param apiName string
param tags object
param apiPort string
param containerImage string
param acrName string
param managedEnvironmentId string

@secure()
param storageAccountKey string

@secure()
param acrAdminPassword string

param telegrafImage string = 'telegraf:1.23.4'
param acrLoginServer string
param sqlCxnString string
param storageNameMount string
param volumeName string
param mountPath string
param userPrincipalId string
param grafanaPrincipalId string
param concurrentRequestsScaleRule string = '50'
param listenAddress string
param metricsListenAddress string
param maxIdleDbCxns string
param maxOpenDbCxns string

var azMonMetricsPublisherRoleDefinitionID = '3913510d-42f4-4e42-8a64-420c390055eb'
var azMonDataReaderRoleDefinitionID = 'b0d8363b-8ddd-447d-831f-62ca05bff136'
var grafanaAdminRoleDefinitionID = '22926164-76b3-42b3-bc55-97df8dab3e41'

resource todoListApi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: apiName
  location: location
  tags: tags
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
          env: [
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 20
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
}

module azMonMetricsPublisherRbac 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-azMonMetricsPublisherRbac'
  params: {
    principalId: todoListApi.identity.principalId
    roleDefinitionID: azMonMetricsPublisherRoleDefinitionID
    principalType: 'ServicePrincipal'
  }
}

module azMonDataReader 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-azMonDataReaderRbac'
  params: {
    principalId: userPrincipalId
    roleDefinitionID: azMonDataReaderRoleDefinitionID
    principalType: 'User'
  }
}

module grafanaAdminRole 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-grafanaAdminRbac'
  params: {
    principalId: userPrincipalId
    roleDefinitionID: grafanaAdminRoleDefinitionID
    principalType: 'User'
  }
}

module grafanaReadAccessLogAnalyticsRole 'rbac-resourcegroup-scope.bicep' = {
  name: 'module-grafanaLogAnalyticsReadRbac'
  params: {
    principalId: grafanaPrincipalId
    roleDefinitionID: grafanaAdminRoleDefinitionID
    principalType: 'ServicePrincipal'
  }
}

output ipAddress string = todoListApi.properties.outboundIpAddresses[0]
output fqdn string = todoListApi.properties.configuration.ingress.fqdn

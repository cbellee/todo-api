param location string
param acrName string
param apiName string = 'todolist'
param apiPort string = '8080'
param containerImage string
param sqlAdminLoginName string = 'dbadmin'
param sqlAdminPassword string

param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var affix = uniqueString(resourceGroup().id)
var containerAppEnvName = 'app-env-vnet-${affix}'
var acrLoginServer = '${acrName}.azurecr.io'
var acrAdminPassword = listCredentials(acr.id, '2021-12-01-preview').passwords[0].value
var workspaceName = 'wks-${affix}'
var sqlServerName = 'sql-server-${affix}'
var sqlDbName = 'todo-list-db'
var aiName = 'ai-${affix}'
var vnetName = 'vnet-${affix}'

var vnetConfig = {
  internal: false
  infrastructureSubnetId: vnet.properties.subnets[0].id
  platformReservedCidr: '10.0.0.0/16'
  platformReservedDnsIP: '10.0.0.2'
  dockerBridgeCidr: '10.1.0.1/16'
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.10.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'aca-infra-subnet'
        properties: {
          addressPrefix: '10.10.1.0/22'
        }
      }
    ]
  }
}

module aiModule 'modules/ai.bicep' = {
  name: 'module-ai'
  params: {
    location: location
    aiName: aiName
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

module wksModule 'modules/wks.bicep' = {
  name: 'module-wks'
  params: {
    location: location
    name: workspaceName
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'module-sql'
  params: {
    adminLoginName: sqlAdminLoginName
    adminLoginPassword: sqlAdminPassword
    location: location
    sqlDbName: sqlDbName
    sqlServerName: sqlServerName
  }
}

module containerAppEnvModule './modules/cappenv.bicep' = {
  name: 'module-capp-env'
  params: {
    name: containerAppEnvName
    location: location
    isInternal: false
    vnetConfig: vnetConfig
    tags: tags
    wksSharedKey: wksModule.outputs.workspaceSharedKey
    aiKey: aiModule.outputs.aiKey
    wksCustomerId: wksModule.outputs.workspaceCustomerId
  }
}

resource todoListApi 'Microsoft.App/containerApps@2022-06-01-preview' = {
  name: apiName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    containerAppEnvModule
  ]
  properties: {
    configuration: {
      activeRevisionsMode: 'multiple'
      secrets: [
        {
          name: 'registry-password'
          value: acrAdminPassword
        }
        {
          name: 'sql-cxn-string'
          value: sql.outputs.cxnString
        }
      ]
      registries: [
        {
          passwordSecretRef: 'registry-password'
          server: acrLoginServer
          username: acr.name
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
    managedEnvironmentId: containerAppEnvModule.outputs.id
    template: {
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
              type: 'Liveness'
              initialDelaySeconds: 15
              failureThreshold: 3
              periodSeconds: 15
              httpGet: {
                port: int(apiPort)
                path: 'healthz/liveness'
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

output fqdn string = todoListApi.properties.configuration.ingress.fqdn

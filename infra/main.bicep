param location string
param timeStamp string = utcNow()
param sqlAdminLoginName string = 'dbadmin'
param fileShareName string
param storageNameMount string = 'storage-mount'
param azMonLocation string = 'australiasoutheast'
param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var affix = uniqueString(resourceGroup().id)
var altName = 'alt-${affix}'
var containerAppEnvName = 'app-env-external-vnet-${affix}'
var workspaceName = 'wks-${affix}'
var azMonName = 'azm-${affix}'
var sqlServerName = 'sql-server-${affix}'
var sqlDbName = 'todo-list-db'
var vnetName = 'vnet-aca-${affix}'
var sqlAdminLoginPassword = '${affix}-${guid(affix)}'
var logAnalyticsReaderRoleID = '73c42c96-874c-492b-b04d-ab87d138a893'

var vnetConfig = {
  internal: false
  infrastructureSubnetId: vnet.properties.subnets[0].id
  platformReservedCidr: '10.0.0.0/16'
  platformReservedDnsIP: '10.0.0.2'
  dockerBridgeCidr: '10.1.0.1/16'
}

module acr 'modules/acr.bicep' = {
  name: 'module-acr-${timeStamp}'
  params: {
    location: location
  }
}

module storage 'modules/stor.bicep' = {
name: 'module-storage-${timeStamp}'
params: {
  fileShareName: fileShareName
  location: location
  }
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
          addressPrefix: '10.10.8.0/21'
        }
      }
    ]
  }
}

module wksModule 'modules/wks.bicep' = {
  name: 'module-wks-${timeStamp}'
  params: {
    name: workspaceName
    azMonName: azMonName
    location: location
    azMonLocation: azMonLocation
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'module-sql-${timeStamp}'
  params: {
    adminLoginName: sqlAdminLoginName
    adminLoginPassword: sqlAdminLoginPassword
    location: location
    sqlDbName: sqlDbName
    sqlServerName: sqlServerName
  }
}

module containerAppEnvModule './modules/cappenv.bicep' = {
  name: 'module-capp-env-${timeStamp}'
  params: {
    name: containerAppEnvName
    location: location
    vnetConfig: vnetConfig
    isZoneRedundant: true
    tags: tags
    wksSharedKey: wksModule.outputs.workspaceSharedKey
    wksCustomerId: wksModule.outputs.workspaceCustomerId
    storageAccountName: storage.outputs.storageAccountName
    shareName: storage.outputs.fileShareName
    storageNameMount: storageNameMount
  }
}

module azMonitorMetricsReaderRole './modules/rbac-subscription-scope.bicep' = {
  name: 'module-azMonitorMetricsReadRbac-${timeStamp}'
  scope: subscription()
  params: {
    principalId: wksModule.outputs.grafanaPrincipalId
    roleDefinitionID: logAnalyticsReaderRoleID
    principalType: 'ServicePrincipal'
  }
}

resource azLoadTest 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: altName
  location: location
  tags: tags
}

// output sqlAdminLoginPassword string = sqlAdminLoginPassword
output acrName string = acr.outputs.acrName
output containerAppEnvironmentId string = containerAppEnvModule.outputs.id
output sqlServerName string = sql.outputs.name
output sqlCxnString string = sql.outputs.cxnString
output storageAccountName string = storage.outputs.storageAccountName

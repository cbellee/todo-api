param location string
param acrName string
param apiName string = 'todolist'
param apiPort string = '8080'
param containerImage string
param sqlAdminLoginName string = 'dbadmin'
param fileShareName string = 'telegraf-share'

@secure()
param storageAccountName string

param storageNameMount string = 'storage-mount'
param mountPath string = '/etc/telegraf'
param userPrincipalId string
param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var affix = uniqueString(resourceGroup().id)
var storageAccountKey = storage.listKeys().keys[0].value
var altName = 'alt-${affix}'
var containerAppEnvName = 'app-env-external-vnet-${affix}'
var acrLoginServer = '${acrName}.azurecr.io'
var acrAdminPassword = acr.listCredentials(acr.apiVersion).passwords[0].value
var workspaceName = 'wks-${affix}'
var azMonName = 'azm-${affix}'
var sqlServerName = 'sql-server-${affix}'
var sqlDbName = 'todo-list-db'
var vnetName = 'vnet-aca-${affix}'
var sqlAdminLoginPassword = '${affix}-${guid(affix)}'
var volumeName = 'azure-file-volume'
var logAnalyticsReaderRoleID = '73c42c96-874c-492b-b04d-ab87d138a893'
var listenAddress = '8080'
var metricsListenAddress = '8081'
var maxIdleDbCxn = '5'
var maxOpenDbCxn = '10'

var vnetConfig = {
  internal: false
  infrastructureSubnetId: vnet.properties.subnets[0].id
  platformReservedCidr: '10.0.0.0/16'
  platformReservedDnsIP: '10.0.0.2'
  dockerBridgeCidr: '10.1.0.1/16'
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: acrName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
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
  name: 'module-wks'
  params: {
    name: workspaceName
    azMonName: azMonName
    location: location
    tags: tags
  }
}

module sql 'modules/sql.bicep' = {
  name: 'module-sql'
  params: {
    adminLoginName: sqlAdminLoginName
    adminLoginPassword: sqlAdminLoginPassword
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
    vnetConfig: vnetConfig
    tags: tags
    wksSharedKey: wksModule.outputs.workspaceSharedKey
    wksCustomerId: wksModule.outputs.workspaceCustomerId
    storageAccountName: storageAccountName
    shareName: fileShareName
    storageAccountKey: storageAccountKey
    storageNameMount: storageNameMount
  }
}

module app 'modules/app.bicep' = {
  name: 'module-app'
  params: {
    userPrincipalId: userPrincipalId
    acrAdminPassword: acrAdminPassword
    acrLoginServer: acrLoginServer
    acrName: acr.name
    apiName: apiName
    apiPort: apiPort
    containerImage: containerImage
    location: location
    managedEnvironmentId: containerAppEnvModule.outputs.id
    sqlCxnString: sql.outputs.cxnString
    storageAccountKey: storageAccountKey
    storageNameMount: storageNameMount
    volumeName: volumeName
    mountPath: mountPath
    grafanaPrincipalId: wksModule.outputs.grafanaPrincipalId
    tags: tags
    listenAddress: listenAddress
    metricsListenAddress: metricsListenAddress
    maxIdleDbCxns: maxIdleDbCxn
    maxOpenDbCxns: maxOpenDbCxn
  }
}

resource sqlFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: '${sqlServerName}/container-app-rule'
  dependsOn: [
    app
    sql
  ]
  properties: {
    startIpAddress: app.outputs.ipAddress
    endIpAddress: app.outputs.ipAddress
  }
}

module azMonitorMetricsReaderRole './modules/rbac-subscription-scope.bicep' = {
  name: 'module-azMonitorMetricsReadRbac'
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

output fqdn string = app.outputs.fqdn
output egressIp string = app.outputs.ipAddress
output sqlAdminLoginPassword string = sqlAdminLoginPassword

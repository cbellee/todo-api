param location string
param acrName string
param apiName string = 'todolist'
param apiPort string = '8080'
param containerImage string
param sqlAdminLoginName string = 'dbadmin'
param fileShareName string = 'telegraf-share'
param storageAccountKey string
param storageNameMount string = 'storage-mount'
param mountPath string = '/etc/telegraf'
param grafanaRegion string = 'australiaeast'

param tags object = {
  environment: 'dev'
  costcode: '1234567890'
}

var affix = uniqueString(resourceGroup().id)
var storageAccountName = 'stor${affix}'
var containerAppEnvName = 'app-env-external-vnet-${affix}'
var acrLoginServer = '${acrName}.azurecr.io'
var acrAdminPassword = listCredentials(acr.id, '2021-12-01-preview').passwords[0].value
var workspaceName = 'wks-${affix}'
var sqlServerName = 'sql-server-${affix}'
var sqlDbName = 'todo-list-db'
var vnetName = 'vnet-aca-${affix}'
var sqlAdminLoginPassword = '${affix}-53058255-87EC-42DC-B645-DE1A61DBEB48'
var volumeName = 'azure-file-volume'

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
          addressPrefix: '10.10.8.0/21'
        }
      }
    ]
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
    grafanaRegion: grafanaRegion
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

module api 'modules/app.bicep' = {
  name: 'module-api'
  params: {
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
    tags: tags
  }
}

resource sqlFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: '${sqlServerName}/container-app-rule'
  dependsOn: [
    api
    sql
  ]
  properties: {
    startIpAddress: api.outputs.ipAddress
    endIpAddress: api.outputs.ipAddress
  }
}


output fqdn string = api.outputs.fqdn
output egressIp string = api.outputs.ipAddress
output sqlAdminLoginPassword string = sqlAdminLoginPassword

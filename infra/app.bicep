param apiName string = 'todolist'
param apiPort string = '8080'
param location string
param acrName string
param grafanaPrincipalId string
param containerImage string
param userPrincipalId string
param mountPath string = '/etc/telegraf'
param containerAppEnvId string
param sqlCxnString string
param storageAccountName string
param storageNameMount string
param sqlServerName string
param tags object

var volumeName = 'azure-file-volume'
var listenAddress = '8080'
var metricsListenAddress = '8081'
var maxIdleDbCxn = '5'
var maxOpenDbCxn = '10'

resource sql 'Microsoft.Sql/servers@2022-11-01-preview' existing = {
  name: sqlServerName
}

module app 'modules/app.bicep' = {
  name: 'module-app'
  params: {
    userPrincipalId: userPrincipalId
    acrName: acrName
    apiName: apiName
    apiPort: apiPort
    containerImage: containerImage
    location: location
    managedEnvironmentId: containerAppEnvId
    sqlCxnString: sqlCxnString
    storageAccountName: storageAccountName
    storageNameMount: storageNameMount
    volumeName: volumeName
    mountPath: mountPath
    grafanaPrincipalId: grafanaPrincipalId
    tags: tags
    listenAddress: listenAddress
    metricsListenAddress: metricsListenAddress
    maxIdleDbCxns: maxIdleDbCxn
    maxOpenDbCxns: maxOpenDbCxn
  }
}

resource sqlFirewallRules 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: 'container-app-rule'
  parent: sql
  dependsOn: [
    app
  ]
  properties: {
    startIpAddress: app.outputs.ipAddress
    endIpAddress: app.outputs.ipAddress
  }
}

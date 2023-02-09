param location string
param name string
param wksCustomerId string
param wksSharedKey string
param tags object
param vnetConfig object
param isZoneRedundant bool = false
param storageAccountName string
param storageAccountKey string
param storageNameMount string
param shareName string

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  location: location
  name: name
  properties: {
    vnetConfiguration: vnetConfig
    zoneRedundant: isZoneRedundant
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: wksCustomerId
        sharedKey: wksSharedKey
      }
    }
  }
  tags: tags
}

resource cAppEnvStorage 'Microsoft.App/managedEnvironments/storages@2022-06-01-preview' = {
  name: storageNameMount
  parent: containerAppEnvironment
  properties: {
    azureFile: {
      accessMode: 'ReadOnly'
      accountKey: storageAccountKey
      accountName: storageAccountName
      shareName: shareName
    }
  }
}

output id string = containerAppEnvironment.id
output name string = containerAppEnvironment.name
output environment object = containerAppEnvironment

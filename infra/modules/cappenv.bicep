param location string
param name string
param wksCustomerId string
param wksSharedKey string
param tags object
param vnetConfig object
param isZoneRedundant bool = false
param storageAccountName string
param storageNameMount string
param shareName string

@secure()
param storageAccountKey string

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

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource cAppEnvStorage 'Microsoft.App/managedEnvironments/storages@2022-06-01-preview' = {
  name: storageNameMount
  parent: containerAppEnvironment
  properties: {
    azureFile: {
      accessMode: 'ReadOnly'
      accountKey: storage.listKeys(storage.apiVersion).keys[0].value
      accountName: storageAccountName
      shareName: shareName
    }
  }
}

output id string = containerAppEnvironment.id
output name string = containerAppEnvironment.name
output environment object = containerAppEnvironment

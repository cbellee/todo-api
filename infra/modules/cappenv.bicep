param location string
param name string
param aiKey string
param wksCustomerId string
param wksSharedKey string
param tags object
param vnetConfig object
param isInternal bool = false
param isZoneRedundant bool = false

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  location: location
  name: name
  properties: {
    daprAIInstrumentationKey: aiKey
    vnetConfiguration: isInternal ? vnetConfig : null
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

output id string = containerAppEnvironment.id
output name string = containerAppEnvironment.name
output cAppEnv object = containerAppEnvironment

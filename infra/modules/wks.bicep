param name string
param azMonName string
param location string
param azMonLocation string
param tags object
param retentionInDays int = 30

@allowed([
  'Standard'
  'PerGB2018'
])
param sku string = 'PerGB2018'

resource wks 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  location: location
  name: name
  tags: tags
  properties: {
    retentionInDays: retentionInDays
    sku: {
      name: sku
    }
  }
}

resource azureMonitorWorkspace 'Microsoft.Monitor/accounts@2021-06-03-preview' = {
  name: azMonName
  location: azMonLocation
  properties: {
  }
}

resource grafana 'Microsoft.Dashboard/grafana@2022-08-01' = {
  name: wks.name
  location: location
  sku: {
    name: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    zoneRedundancy: 'Disabled'
    apiKey: 'Disabled'
    deterministicOutboundIP: 'Disabled'
    grafanaIntegrations: {
      azureMonitorWorkspaceIntegrations: [
        {
          azureMonitorWorkspaceResourceId: azureMonitorWorkspace.id
        }
      ]
    }
  }
}

output workspaceId string = wks.id
output workspaceName string = wks.name
output azMonWorkspaceName string = azureMonitorWorkspace.name
output workspaceSharedKey string = wks.listKeys().primarySharedKey
output workspaceCustomerId string = wks.properties.customerId
output grafanaPrincipalId string = grafana.identity.principalId

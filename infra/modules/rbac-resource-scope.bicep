param acrName string  
param umidName string
param acrPullRoleDefinitionId string

resource umid 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: umidName
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: acrName
}

resource umidAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(umidName, resourceGroup().id, 'acrPullRoleAssignment')
  scope: acr
  properties: {
    principalId: umid.properties.principalId
    roleDefinitionId: az.resourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionId)
    principalType: 'ServicePrincipal'
  }
}

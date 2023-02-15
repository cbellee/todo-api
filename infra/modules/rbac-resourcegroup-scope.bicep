param principalId string
param roleDefinitionID string
@allowed(
  [
    'ServicePrincipal'
    'User'
    'Device'
    'Group'
    'ForeignGroup'
  ]
)
param principalType string

resource RBACRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, roleDefinitionID, resourceGroup().id)
  properties: {
    principalId: principalId
    roleDefinitionId: az.resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalType: principalType
  }
}

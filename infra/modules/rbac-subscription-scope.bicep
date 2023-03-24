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

targetScope = 'subscription'

resource RBACRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(principalId, roleDefinitionID, subscription().id)
  properties: {
    principalId: principalId
    roleDefinitionId: az.resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionID)
    principalType: principalType
  }
}

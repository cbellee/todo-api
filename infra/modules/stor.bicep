param location string
param fileShareName string

var affix = uniqueString(resourceGroup().id)
var storageAccountName = 'stor${affix}'

resource stor 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  name: 'default'
  parent: stor
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  name: fileShareName
  parent: fileService
  properties: {
    accessTier: 'Hot'
    enabledProtocols: 'SMB'
    shareQuota: 1024
  }
}

output storageAccountName string = stor.name
output fileShareName string = fileShare.name

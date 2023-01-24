param location string
param sqlServerName string
param sqlDbName string
param adminLoginName string = 'dbadmin'
param adminLoginPassword string

resource sqlserver 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: adminLoginName
    administratorLoginPassword: adminLoginPassword
    /* administrators: {
      administratorType: 'ActiveDirectory'
      login: 'dbadmin'
      principalType: 'Application'
      tenantId: tenant().tenantId
    } */
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDbName
  location: location
  parent: sqlserver
  sku: {
    name: 'Basic'
  }
}

output cxnString string = 'Server=tcp:${sqlserver.properties.fullyQualifiedDomainName},1433;Initial Catalog=${sqlDbName};Persist Security Info=False;User ID=${adminLoginName};Password=${adminLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

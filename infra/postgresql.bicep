// PostgreSQL Flexible Server with Burstable (Serverless) SKU
// Reference: https://learn.microsoft.com/azure/postgresql/flexible-server/

param location string = resourceGroup().location
param environment string
param administratorLogin string = 'dbadmin'
@secure()
param administratorLoginPassword string
param cicdServicePrincipalId string
param keyVaultName string

// PostgreSQL Server Name (must be globally unique)
var postgresServerName = 'postgres-private-miner-${environment}-${uniqueString(resourceGroup().id)}'
var databaseName = 'private_miner'

// PostgreSQL Flexible Server - Burstable SKU (Serverless)
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'  // Burstable tier - 1 vCore, 2 GiB RAM
    tier: 'Burstable'
  }
  properties: {
    version: '16'  // Latest PostgreSQL version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: 32  // Minimum: 32 GB
      autoGrow: 'Enabled'  // Auto-scale storage as needed
    }
    backup: {
      backupRetentionDays: 7  // Minimum retention for dev
      geoRedundantBackup: 'Disabled'  // Disabled for cost savings in dev
    }
    highAvailability: {
      mode: 'Disabled'  // HA not supported on Burstable tier
    }
    availabilityZone: '1'  // Single availability zone
  }
}

// Firewall Rule: Allow Azure Services
// This allows App Service to connect to PostgreSQL
resource firewallRuleAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-08-01' = {
  name: 'AllowAllAzureServices'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-08-01' = {
  name: databaseName
  parent: postgresServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// Store PostgreSQL credentials in Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource postgresHostSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgres-host'
  parent: keyVault
  properties: {
    value: postgresServer.properties.fullyQualifiedDomainName
  }
}

resource postgresUserSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgres-user'
  parent: keyVault
  properties: {
    value: administratorLogin
  }
}

resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgres-password'
  parent: keyVault
  properties: {
    value: administratorLoginPassword
  }
}

resource postgresDatabaseSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'postgres-database'
  parent: keyVault
  properties: {
    value: databaseName
  }
}

// Outputs
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output databaseName string = databaseName
output connectionString string = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Database=${databaseName};Port=5432;Username=${administratorLogin};SSL Mode=Require;'

// ============================================================================
// Azure Key Vault for Private Miner
// ============================================================================
// Purpose: Store sensitive secrets like CLIENT_SECRET
// Access: CI/CD Service Principal + Local developers via Azure CLI
// ============================================================================

@description('Key Vault name')
param keyVaultName string

@description('Location for Key Vault')
param location string

@description('CI/CD Service Principal Object ID for Key Vault access')
param cicdServicePrincipalId string

@description('Entra ID Tenant ID')
param tenantId string

// ============================================================================
// Key Vault
// ============================================================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true  // Use RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'  // Allow access from GitHub Actions and local dev
  }
}

// Grant CI/CD Service Principal "Key Vault Secrets Officer" role
// This allows CI/CD to set and get secrets
resource cicdSecretsOfficerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, cicdServicePrincipalId, 'Key Vault Secrets Officer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')  // Key Vault Secrets Officer
    principalId: cicdServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// Outputs
// ============================================================================

output keyVaultName string = keyVault.name
output keyVaultId string = keyVault.id

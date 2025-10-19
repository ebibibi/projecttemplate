// app-service-container.bicep
// Azure App Service for Containers - runs Docker images from ACR

@description('Base name for the application')
param appName string

@description('Environment name (dev, staging, prod)')
param environmentName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('ACR login server (e.g., myregistry.azurecr.io)')
param acrLoginServer string

@description('ACR username')
param acrUsername string

@description('ACR password')
@secure()
param acrPassword string

@description('Docker image name with tag')
param containerImage string = 'private-miner-web:latest'

@description('App Service Plan SKU')
@allowed([
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1V2'
  'P2V2'
  'P3V2'
])
param appServicePlanSku string = 'B1'

@description('Microsoft Entra ID Authority URL')
@secure()
param authority string

@description('Microsoft Entra ID Client ID')
@secure()
param clientId string

@description('Microsoft Entra ID Client Secret')
@secure()
param clientSecret string

@description('OAuth Redirect URI')
param redirectUri string

@description('Microsoft Graph API Scopes')
param scope string = 'User.Read Files.Read.All Sites.Read.All GroupMember.Read.All'

@description('Microsoft Graph API Endpoint')
param endpoint string = 'https://graph.microsoft.com/v1.0/me'

@description('Flask session secret key')
@secure()
param sessionSecret string

@description('Azure OpenAI Endpoint')
param azureOpenaiEndpoint string

@description('Azure OpenAI API Key')
@secure()
param azureOpenaiApiKey string

@description('Azure OpenAI Deployment Name (GPT-4o)')
param azureOpenaiDeploymentName string = 'gpt-4o'

@description('Azure OpenAI API Version')
param azureOpenaiApiVersion string = '2024-08-01-preview'

@description('Key Vault name for secret references')
param keyVaultName string

@description('PostgreSQL connection string (from Key Vault)')
@secure()
param postgresConnectionString string = '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/postgres-connection-string/)'

// Variables
var appServicePlanName = '${appName}-plan-${environmentName}'
var appServiceName = '${appName}-${environmentName}'

// App Service Plan (Linux)
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    tier: appServicePlanSku == 'B1' ? 'Basic' : (contains(appServicePlanSku, 'S') ? 'Standard' : 'PremiumV2')
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
  }
}

// App Service (Web App for Containers)
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  kind: 'app,linux,container'
  identity: {
    type: 'SystemAssigned'  // Enable Managed Identity for Key Vault access
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${containerImage}'
      alwaysOn: appServicePlanSku != 'F1' // Always On not available in Free tier
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        // Docker Registry Settings
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrLoginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acrPassword
        }
        {
          name: 'WEBSITES_PORT'
          value: '8000'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        // Application Settings
        {
          name: 'AUTHORITY'
          value: authority
        }
        {
          name: 'CLIENT_ID'
          value: clientId
        }
        {
          name: 'CLIENT_SECRET'
          value: clientSecret
        }
        {
          name: 'REDIRECT_URI'
          value: redirectUri
        }
        {
          name: 'SCOPE'
          value: scope
        }
        {
          name: 'ENDPOINT'
          value: endpoint
        }
        {
          name: 'SESSION_SECRET'
          value: sessionSecret
        }
        // Azure OpenAI Settings
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: azureOpenaiEndpoint
        }
        {
          name: 'AZURE_OPENAI_API_KEY'
          value: azureOpenaiApiKey
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
          value: azureOpenaiDeploymentName
        }
        {
          name: 'AZURE_OPENAI_API_VERSION'
          value: azureOpenaiApiVersion
        }
        // Agent Framework specific environment variables
        {
          name: 'AZURE_OPENAI_CHAT_DEPLOYMENT_NAME'
          value: azureOpenaiDeploymentName
        }
        {
          name: 'AZURE_OPENAI_RESPONSES_DEPLOYMENT_NAME'
          value: azureOpenaiDeploymentName
        }
        {
          name: 'AZURE_OPENAI_RESPONSES_API_VERSION'
          value: azureOpenaiApiVersion
        }
        // PostgreSQL Database Settings (from Key Vault)
        {
          name: 'POSTGRES_HOST'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=postgres-host)'
        }
        {
          name: 'POSTGRES_USER'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=postgres-user)'
        }
        {
          name: 'POSTGRES_PASSWORD'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=postgres-password)'
        }
        {
          name: 'POSTGRES_DATABASE'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=postgres-database)'
        }
        {
          name: 'POSTGRES_PORT'
          value: '5432'
        }
        {
          name: 'POSTGRES_SSLMODE'
          value: 'require'
        }
        // Enable container logging
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
      ]
    }
  }
}

// Reference existing Key Vault for role assignment
resource keyVaultResource 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Grant App Service Managed Identity "Key Vault Secrets User" role
// This allows App Service to read secrets from Key Vault
resource appServiceKeyVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, appService.id, 'Key Vault Secrets User')
  scope: keyVaultResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')  // Key Vault Secrets User
    principalId: appService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'
output appServiceName string = appService.name
output appServiceHostName string = appService.properties.defaultHostName
output appServicePrincipalId string = appService.identity.principalId

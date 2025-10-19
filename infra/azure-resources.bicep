// ============================================================================
// Azure リソース デプロイ テンプレート
// ============================================================================
//
// このBicepテンプレートは以下のリソースをデプロイします：
// - Azure Container Registry (ACR) - Dockerイメージの保存
// - Azure Key Vault - シークレット管理
// - Azure App Service (Linux Container) - Webアプリケーション
//
// オプション（コメントを外して有効化）：
// - Azure OpenAI Service - GPT-4等のAIモデル
// - PostgreSQL Flexible Server - データベース
//
// 使用方法:
// 1. `appName` 変数をプロジェクト名に変更
// 2. 必要に応じてOpenAI/PostgreSQLのコメントを外す
// 3. GitHub Actions の deploy.yml から呼び出される
//
// ============================================================================

targetScope = 'subscription'

// ============================================================================
// Parameters
// ============================================================================

@description('環境名 (dev, staging, prod)')
param environment string = 'dev'

@description('Azure リソースのロケーション')
param location string = 'japaneast'

@description('OpenAI リソースのロケーション')
param openaiLocation string = 'eastus'

@description('App Service Plan SKU')
@allowed([
  'B1'
  'B2'
  'S1'
  'S2'
  'P1V2'
  'P2V2'
])
param appServicePlanSku string = 'B1'

@description('Session secret for the application')
param sessionSecret string = newGuid()

@description('Entra ID Application ID (from Phase 1)')
param applicationId string

@description('CI/CD Service Principal Object ID for Key Vault access')
param cicdServicePrincipalId string

@description('Entra ID Tenant ID')
param tenantId string

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string = newGuid()

// ============================================================================
// Variables
// ============================================================================

// TODO: プロジェクト名を変更してください (例: 'my-app', 'contoso-web')
var appName = 'your-project-name'
var resourceGroupName = '${appName}-${environment}-rg'
var openaiResourceGroupName = '${appName}-openai-rg'
var keyVaultName = 'kv-${appName}-${environment}'
var registryName = '${replace(appName, '-', '')}${environment}'  // ACR names must be alphanumeric only
var openaiName = '${appName}-openai-${environment}'
var appServiceName = '${appName}-${environment}'

// ============================================================================
// Resource Groups
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// TODO: Azure OpenAI を使用する場合は以下のコメントを外してください
/*
resource openaiRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: openaiResourceGroupName
  location: openaiLocation
}
*/

// ============================================================================
// Azure Resources - Main Resource Group
// ============================================================================

module keyVault 'key-vault.bicep' = {
  scope: rg
  name: 'key-vault-deployment'
  params: {
    keyVaultName: keyVaultName
    location: location
    cicdServicePrincipalId: cicdServicePrincipalId
    tenantId: tenantId
  }
}

module containerRegistry 'container-registry.bicep' = {
  scope: rg
  name: 'container-registry-deployment'
  params: {
    registryName: registryName
    location: location
  }
}

// ============================================================================
// Azure Resources - OpenAI Resource Group (オプション)
// ============================================================================

// TODO: Azure OpenAI を使用する場合は、以下のコメントを外してください
/*
module openai 'openai.bicep' = {
  scope: openaiRg
  name: 'openai-deployment'
  params: {
    openaiName: openaiName
    location: openaiLocation
    gpt4oDeploymentName: 'gpt-4o'
  }
}
*/

// ============================================================================
// PostgreSQL Database (オプション - 永続データストレージ)
// ============================================================================

// TODO: PostgreSQL を使用する場合は、以下のコメントを外してください
/*
module postgres 'postgresql.bicep' = {
  scope: rg
  name: 'postgres-deployment'
  params: {
    location: location
    environment: environment
    administratorLoginPassword: postgresAdminPassword
    cicdServicePrincipalId: cicdServicePrincipalId
    keyVaultName: keyVaultName
  }
  dependsOn: [
    keyVault
  ]
}
*/

// ============================================================================
// App Service (Dockerコンテナ)
// ============================================================================

module appService 'app-service-container.bicep' = {
  scope: rg
  name: 'app-service-deployment'
  params: {
    appName: appName
    environmentName: environment
    location: location
    acrLoginServer: '${registryName}.azurecr.io'
    acrUsername: containerRegistry.outputs.acrUsername
    acrPassword: containerRegistry.outputs.acrPassword
    containerImage: '${appName}-web:latest'
    appServicePlanSku: appServicePlanSku
    authority: 'https://login.microsoftonline.com/organizations'
    clientId: applicationId
    clientSecret: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=client-secret-${environment})'
    redirectUri: 'https://${appServiceName}.azurewebsites.net/redirect'
    // TODO: 必要な Microsoft Graph API スコープを設定してください
    scope: 'User.Read'
    sessionSecret: sessionSecret
    // TODO: Azure OpenAI を使用する場合は以下を有効化してください
    azureOpenaiEndpoint: '' // openai.outputs.openaiEndpoint
    azureOpenaiApiKey: '' // 'placeholder-will-be-updated-by-workflow'
    azureOpenaiDeploymentName: '' // 'gpt-4o'
    keyVaultName: keyVaultName
  }
  dependsOn: [
    keyVault
    containerRegistry
    // TODO: OpenAI/PostgreSQL を使用する場合は依存関係を追加してください
    // openai
    // postgres
  ]
}

// ============================================================================
// Outputs
// ============================================================================

output resourceGroupName string = rg.name
output acrName string = containerRegistry.outputs.acrName
output appServiceUrl string = appService.outputs.appServiceUrl

// TODO: OpenAI/PostgreSQL を使用する場合は以下のコメントを外してください
/*
output openaiResourceGroupName string = openaiRg.name
output openaiEndpoint string = openai.outputs.openaiEndpoint
output postgresServerName string = postgres.outputs.postgresServerName
output postgresServerFqdn string = postgres.outputs.postgresServerFqdn
output postgresDatabaseName string = postgres.outputs.databaseName
*/

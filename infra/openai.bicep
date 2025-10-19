// openai.bicep
// Azure OpenAI Service for Private Miner

@description('Name of the Azure OpenAI resource')
param openaiName string

@description('Location for the Azure OpenAI resource')
param location string = resourceGroup().location

@description('SKU name for Azure OpenAI')
@allowed([
  'S0'
])
param skuName string = 'S0'

@description('Deployment name for GPT-4o model')
param gpt4oDeploymentName string = 'gpt-4o'

@description('Deployment name for text-embedding-3-large model')
param embeddingDeploymentName string = 'text-embedding-3-large'

resource openai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openaiName
  location: location
  kind: 'OpenAI'
  sku: {
    name: skuName
  }
  properties: {
    customSubDomainName: openaiName
    publicNetworkAccess: 'Enabled'
  }
}

// Deploy GPT-4o model
resource gpt4oDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openai
  name: gpt4oDeploymentName
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-08-06'
    }
  }
}

// Deploy text-embedding-3-large model
resource embeddingDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openai
  name: embeddingDeploymentName
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-large'
      version: '1'
    }
  }
  dependsOn: [
    gpt4oDeployment
  ]
}

// Outputs
output openaiEndpoint string = openai.properties.endpoint
output openaiName string = openai.name
output openaiId string = openai.id
output gpt4oDeploymentName string = gpt4oDeployment.name
output embeddingDeploymentName string = embeddingDeployment.name

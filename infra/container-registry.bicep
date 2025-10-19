// container-registry.bicep
// Azure Container Registry for storing Docker images

@description('Name of the container registry (must be globally unique, lowercase, alphanumeric only)')
param registryName string

@description('Location for the container registry')
param location string = resourceGroup().location

@description('SKU for the container registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'

@description('Enable admin user for the registry')
param adminUserEnabled bool = true

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: registryName
  location: location
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: 'Enabled'
  }
}

// Outputs
output loginServer string = containerRegistry.properties.loginServer
output registryName string = containerRegistry.name
output registryId string = containerRegistry.id
output acrName string = containerRegistry.name
output acrUsername string = containerRegistry.listCredentials().username
output acrPassword string = containerRegistry.listCredentials().passwords[0].value

targetScope = 'resourceGroup'

param location string = resourceGroup().location
param githubRepository string
@description('Subject OIDC exato do repositório para o environment production, incluindo IDs quando aplicável.')
param productionSubject string
param wandbProject string = 'mlops-2026-2'
param wandbModels string
@secure()
param wandbApiKey string
@secure()
param mongoUrl string
param mongoDb string = 'intent_classifier'

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'intent-clf-env'
  location: location
  properties: {}
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'intent-clf'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        allowInsecure: false
      }
      secrets: [
        { name: 'wandb-key', value: wandbApiKey }
        { name: 'mongo-url', value: mongoUrl }
      ]
    }
    template: {
      containers: [
        {
          name: 'intent-clf'
          image: 'ghcr.io/${toLower(githubRepository)}:v1.0.0'
          resources: { cpu: 2, memory: '4Gi' }
          env: [
            { name: 'WANDB_API_KEY', secretRef: 'wandb-key' }
            { name: 'MONGO_URL', secretRef: 'mongo-url' }
            { name: 'WANDB_PROJECT', value: wandbProject }
            { name: 'WANDB_MODELS', value: wandbModels }
            { name: 'MONGO_DB', value: mongoDb }
            { name: 'APP_VERSION', value: 'v1.0.0' }
          ]
          probes: [
            {
              type: 'Startup'
              tcpSocket: { port: 8000 }
              periodSeconds: 10
              failureThreshold: 60
            }
          ]
        }
      ]
      scale: { minReplicas: 0, maxReplicas: 1 }
    }
  }
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'intent-clf-deploy'
  location: location
}

resource federated 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'github-production'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    audiences: ['api://AzureADTokenExchange']
    subject: productionSubject
  }
}

var contributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, identity.id, contributor)
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributor
  }
}

output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
output azureClientId string = identity.properties.clientId
output azureTenantId string = tenant().tenantId
output azureSubscriptionId string = subscription().subscriptionId

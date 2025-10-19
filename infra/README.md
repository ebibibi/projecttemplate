# Azure Infrastructure Setup

このディレクトリには、Azure DevContainer プロジェクトのインフラストラクチャセットアップ用 Bicep テンプレートが含まれています。

## 📋 前提条件

### 必須ツール
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (最新版)
- [Bicep CLI](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) (`az bicep install`)
- [PowerShell 7.0+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (推奨)

### 必要な権限
- **Azure サブスクリプション**: Contributor ロール
- **Entra ID (Azure AD)**: Application Administrator ロール (Entra ID アプリを作成する場合)

## 🚀 クイックスタート

### 1. プロジェクト名の設定

`azure-resources.bicep` を編集して、プロジェクト名を変更してください：

```bicep
// TODO: プロジェクト名を変更してください (例: 'my-app', 'contoso-web')
var appName = 'your-project-name'
```

### 2. GitHub Actions の設定

`.github/workflows/deploy.yml` でも同じプロジェクト名を使用してください：

```yaml
env:
  ENVIRONMENT: ${{ github.event.inputs.environment || 'dev' }}
  LOCATION: japaneast
  REGISTRY_NAME: yourprojectname${{ github.event.inputs.environment || 'dev' }}
  APP_NAME: your-project-name-${{ github.event.inputs.environment || 'dev' }}
  IMAGE_NAME: your-project-name-web
```

### 3. デプロイ

GitHub Actions ワークフローを実行してデプロイします：

```bash
# GitHub CLI を使用
gh workflow run deploy.yml --ref main

# または Azure Portal から "Actions" タブで手動実行
```

## 📁 Bicep ファイル構成

| ファイル | 説明 | 必須 |
|---------|------|-----|
| `azure-resources.bicep` | メインテンプレート (サブスクリプションレベル) | ✅ 必須 |
| `key-vault.bicep` | Azure Key Vault (シークレット管理) | ✅ 必須 |
| `container-registry.bicep` | Azure Container Registry (ACR) | ✅ 必須 |
| `app-service-container.bicep` | App Service (Linux Container) | ✅ 必須 |
| `openai.bicep` | Azure OpenAI Service | ⚙️ オプション |
| `postgresql.bicep` | PostgreSQL Flexible Server | ⚙️ オプション |
| `bicepconfig.json` | Bicep コンパイラ設定 | ✅ 必須 |

## 🔧 オプション機能の有効化

### Azure OpenAI を使用する場合

`azure-resources.bicep` の以下のセクションのコメントを外してください：

```bicep
// 1. OpenAI Resource Group
resource openaiRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: openaiResourceGroupName
  location: openaiLocation
}

// 2. OpenAI Module
module openai 'openai.bicep' = {
  scope: openaiRg
  name: 'openai-deployment'
  params: {
    openaiName: openaiName
    location: openaiLocation
    gpt4oDeploymentName: 'gpt-4o'
  }
}

// 3. App Service の params
azureOpenaiEndpoint: openai.outputs.openaiEndpoint
azureOpenaiApiKey: 'placeholder-will-be-updated-by-workflow'
azureOpenaiDeploymentName: 'gpt-4o'

// 4. dependsOn
dependsOn: [
  keyVault
  containerRegistry
  openai  // ← 追加
]

// 5. Outputs
output openaiEndpoint string = openai.outputs.openaiEndpoint
```

### PostgreSQL を使用する場合

`azure-resources.bicep` の以下のセクションのコメントを外してください：

```bicep
// 1. PostgreSQL Module
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

// 2. App Service の dependsOn
dependsOn: [
  keyVault
  containerRegistry
  postgres  // ← 追加
]

// 3. Outputs
output postgresServerName string = postgres.outputs.postgresServerName
output postgresServerFqdn string = postgres.outputs.postgresServerFqdn
output postgresDatabaseName string = postgres.outputs.databaseName
```

## 🔑 Key Vault 設定 (必須)

このテンプレートでは、すべての設定を **Azure Key Vault** で管理します（`.env` ファイルは使用しません）。

### ローカル開発での Key Vault アクセス

```bash
# Azure CLI でログイン
az login

# Key Vault Secrets User ロールを自分に付与
MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --assignee $MY_OBJECT_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/{subscription-id}/resourceGroups/your-project-name-dev-rg/providers/Microsoft.KeyVault/vaults/kv-your-project-name-dev
```

### アプリケーションでの Key Vault 読み込み

```python
# Python 例
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://kv-your-project-name-dev.vault.azure.net/", credential=credential)

client_id = client.get_secret("client-id").value
client_secret = client.get_secret("client-secret-dev").value
```

## 🔍 トラブルシューティング

### "Application Administrator role required" エラー

**原因**: Entra ID でアプリケーションを作成する権限がありません。

**解決策**:
1. Azure Portal → Entra ID → Roles and administrators
2. 自分に "Application Administrator" ロールを付与
3. または、グローバル管理者に依頼

### "Key Vault access denied" エラー

**原因**: Key Vault Secrets User ロールが付与されていません。

**解決策**:
```bash
# 自分のオブジェクトIDを取得
az ad signed-in-user show --query id -o tsv

# ロールを付与
az role assignment create \
  --assignee <your-object-id> \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}
```

### Bicep デプロイが失敗する

**確認事項**:
```bash
# Bicep のバージョン確認
az bicep version

# Bicep のアップグレード
az bicep upgrade

# Bicep のビルドテスト
az bicep build --file infra/azure-resources.bicep
```

## 📚 参考リンク

- [Azure CLI リファレンス](https://learn.microsoft.com/cli/azure/)
- [Bicep 言語リファレンス](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/)
- [Azure App Service - Custom Container](https://learn.microsoft.com/azure/app-service/configure-custom-container)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)

## 💡 ベストプラクティス

### 1. 環境ごとにリソースを分離

```yaml
# 開発環境
environment: dev
location: japaneast

# 本番環境
environment: prod
location: japaneast
```

### 2. Key Vault で設定を一元管理

- ❌ `.env` ファイルは使用しない
- ✅ すべてのシークレットを Key Vault に保存
- ✅ ローカルでも Azure でも Key Vault を参照

### 3. Bicep を優先、スクリプトは最小限

- ✅ リソース作成は Bicep で宣言的に管理
- ✅ スクリプトは Bicep で取得できない値のみ
- ✅ 冪等性を保つ（何度実行しても同じ結果）

### 4. CI/CD ワークフローは単一ファイル

- ✅ `.github/workflows/deploy.yml` のみ
- ❌ 個別のワークフローファイルは作成しない
- ✅ 3つのジョブで管理（Entra ID → Azure Resources → Build & Deploy）

---

**最終更新日**: 2025-10-19

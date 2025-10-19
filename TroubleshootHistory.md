# Troubleshoot History - Azure DevContainer Project

このドキュメントには、Azure DevContainer プロジェクトで発生した問題とその解決方法を記録しています。

**目的**: 同じ問題で再度苦労しないよう、トラブルシューティングの知見を共有する

---

## 📋 目次

1. [Key Vaultからの設定読み込み失敗](#1-key-vaultからの設定読み込み失敗)
2. [App Serviceが最新のコンテナを使用しない問題](#2-app-serviceが最新のコンテナを使用しない問題)
3. [Bicep デプロイエラー](#3-bicep-デプロイエラー)
4. [Azure 権限問題](#4-azure-権限問題)
5. [GitHub Actions ワークフロー失敗](#5-github-actions-ワークフロー失敗)

---

## 1. Key Vaultからの設定読み込み失敗

### 症状

```
Missing required secrets from Key Vault 'kv-myapp-dev': client-secret
HTTP 500 Internal Server Error
```

App Serviceのログに以下のエラーが記録：
```
ERROR - ❌ Configuration Error: Missing required secrets from Key Vault 'kv-myapp-dev': client-secret
```

### 原因

- **古いDockerコンテナが起動時の失敗した設定をキャッシュしていた**
- Key Vaultには実際にシークレットが存在していたが、コンテナが古い状態で動作
- CI/CDでイメージを更新しても、App Serviceが古いコンテナを使い続けていた

### 調査手順

1. **Key Vaultの確認**
   ```bash
   az keyvault secret list --vault-name kv-myapp-dev -o table
   ```
   → シークレットは存在していた

2. **App Serviceのログ確認**
   ```bash
   az webapp log tail --name myapp-dev --resource-group myapp-dev-rg
   ```
   → 起動時のエラーが確認できた

3. **コンテナの状態確認**
   ```bash
   az webapp show --name myapp-dev --resource-group myapp-dev-rg --query "state"
   ```
   → "Running" だったが、古い設定のまま

### 解決方法

**App Serviceの完全再起動:**

```bash
# 1. App Serviceを完全停止
az webapp stop --name myapp-dev --resource-group myapp-dev-rg

# 2. 数秒待つ
sleep 5

# 3. App Serviceを再起動（新しいコンテナがデプロイされる）
az webapp start --name myapp-dev --resource-group myapp-dev-rg

# 4. ログで起動を確認
az webapp log tail --name myapp-dev --resource-group myapp-dev-rg
```

### 結果

- ✅ 新しいコンテナがデプロイされ、Key Vaultから正常に設定を読み込めるようになった
- ✅ HTTP 200 OK レスポンス
- ✅ すべての環境変数が正しく注入された

### 教訓

1. **設定変更後は必ず完全再起動**
   - `az webapp restart` だけでは不十分な場合がある
   - `stop` → `start` で確実に新しいコンテナをデプロイ

2. **Key Vaultの存在確認だけでなく、アプリ側のログも確認**
   - 設定が存在していても、コンテナが古い状態だと読み込めない

3. **CI/CDでイメージ更新後、App Serviceが新しいコンテナを使っているか確認**
   - Azure Portalの「コンテナ設定」→「ログ」で確認

---

## 2. App Serviceが最新のコンテナを使用しない問題

### 症状

- CI/CDパイプラインでDockerイメージをビルド・プッシュしても、App Serviceが古いコンテナイメージを使い続ける
- コードを変更してデプロイしても、古いバージョンが動作している
- `az webapp restart` を実行しても、新しいコンテナがpullされない

### 原因

**App Serviceのコンテナキャッシュメカニズム:**

1. **イメージタグが同じ（`latest`）だと更新されない**
   - App Serviceは `latest` タグのイメージをキャッシュする
   - 新しいイメージがACRにpushされても、ローカルキャッシュを使い続ける

2. **`az webapp restart` は既存コンテナの再起動のみ**
   - 新しいイメージのpullは実行されない
   - コンテナプロセスが再起動するだけ

3. **CI/CDパイプラインの不完全な実装**
   - 明示的なコンテナイメージ更新コマンドがない

### 調査手順

1. **現在のCI/CDパイプラインを確認**
   ```bash
   cat .github/workflows/deploy.yml
   ```
   → コンテナイメージの明示的な更新がない

2. **Microsoft Learn で公式ドキュメント確認**
   - `az webapp config container set` コマンドで明示的に更新可能
   - Continuous Deployment (Webhook) でACRからの自動デプロイが可能

### 解決方法

#### **方法1: コンテナ設定を明示的に更新（推奨）**

**`.github/workflows/deploy.yml` の修正:**

```yaml
# ❌ 現在の実装（不完全）
- name: Restart App Service
  run: |
    az webapp restart \
      --name ${{ env.APP_NAME }} \
      --resource-group myapp-${{ env.ENVIRONMENT }}-rg
```

```yaml
# ✅ 改善後（明示的にコンテナイメージを更新）
- name: Update Container Image
  run: |
    az webapp config container set \
      --name ${{ env.APP_NAME }} \
      --resource-group myapp-${{ env.ENVIRONMENT }}-rg \
      --container-image-name ${{ env.REGISTRY_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ github.sha }}

- name: Wait for Container Update
  run: sleep 30

- name: Restart App Service
  run: |
    az webapp restart \
      --name ${{ env.APP_NAME }} \
      --resource-group myapp-${{ env.ENVIRONMENT }}-rg

- name: Wait for App Service to start
  run: sleep 60
```

**重要な変更点:**
1. **`az webapp config container set`** - コンテナイメージを明示的に更新
2. **`${{ github.sha }}`タグを使用** - `latest`ではなくコミットSHAで特定
3. **1回のrestartで十分** - イメージ更新後は1回の再起動で新しいコンテナが起動

#### **方法2: Continuous Deployment (Webhook) を有効化**

**Bicep での設定 (`infra/app-service-container.bicep`):**

```bicep
resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: appServiceName
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acrLoginServer}/${containerImage}'
      // Continuous Deployment を有効化
      appSettings: [
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
      ]
    }
  }
}
```

**メリット:**
- ✅ ACRにイメージがpushされたら自動的にApp Serviceが更新される
- ✅ CI/CDパイプラインで明示的な更新が不要
- ✅ Webhookが自動的に設定される

### 結果

**方法1（コンテナ設定更新）を実装後:**
- ✅ CI/CDパイプラインが新しいイメージを確実にデプロイ
- ✅ コミットSHAタグで明確なバージョン管理
- ✅ `az webapp restart` の2回実行が不要に

**方法2（Webhook）を実装後:**
- ✅ ACRへのpushで自動デプロイ
- ✅ CI/CDパイプラインでの手動操作が不要
- ✅ デプロイ時間の短縮

### 教訓

1. **`az webapp restart` だけでは新しいイメージをpullしない**
   - `az webapp config container set` で明示的に更新する
   - または `stop` → `start` で完全再起動

2. **イメージタグは `latest` よりもSHAを使用**
   ```yaml
   tags: |
     ${{ env.REGISTRY_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:${{ github.sha }}
     ${{ env.REGISTRY_NAME }}.azurecr.io/${{ env.IMAGE_NAME }}:latest
   ```
   - デプロイ時は `${{ github.sha }}` を指定
   - `latest` はフォールバック用

3. **Continuous Deployment (Webhook) の活用**
   - `DOCKER_ENABLE_CI: 'true'` でACRからの自動デプロイ
   - 手動操作のミスを防ぐ

4. **デプロイ完了の確認**
   ```bash
   # HTTPステータス確認
   curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://myapp-dev.azurewebsites.net
   ```

5. **CI/CDパイプラインの冪等性**
   - 何度実行しても同じ結果になるように設計
   - 明示的なイメージ更新コマンドを含める

---

## 3. Bicep デプロイエラー

### 症状

```
ERROR: The template deployment failed because of policy violation
```

または

```
ERROR: Resource group 'myapp-dev-rg' could not be found
```

### 原因

1. **Azure Policy 違反**
   - 組織のAzure Policyで許可されていないリソースタイプやSKUを使用している

2. **リソースグループが存在しない**
   - サブスクリプションレベルデプロイ (`targetScope = 'subscription'`) でリソースグループを作成していない

3. **Bicep バージョンの不一致**
   - 古いBicep CLIを使用している

### 解決方法

#### Azure Policy 違反の場合

```bash
# 1. エラーメッセージからポリシー名を特定
# ERROR: Policy assignment 'require-tags' violated

# 2. ポリシーの詳細を確認
az policy assignment show --name "require-tags"

# 3. Bicepテンプレートを修正してポリシーに準拠
```

#### リソースグループが存在しない場合

```bicep
// ✅ サブスクリプションレベルデプロイでリソースグループを作成
targetScope = 'subscription'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

// モジュールでリソースグループをスコープとして指定
module appService 'app-service.bicep' = {
  scope: rg
  name: 'app-service-deployment'
  params: { ... }
}
```

#### Bicep バージョンの問題

```bash
# Bicep のバージョン確認
az bicep version

# Bicep のアップグレード
az bicep upgrade

# Bicep のビルドテスト
az bicep build --file infra/azure-resources.bicep
```

### 教訓

1. **Azure Policy を事前に確認**
   - デプロイ前に組織のポリシーを確認
   - 許可されているリソースタイプ・SKU・ロケーションを把握

2. **Bicep は最新版を使用**
   - `az bicep upgrade` で定期的にアップグレード

3. **ローカルでBicepをビルドしてエラーを早期発見**
   ```bash
   az bicep build --file infra/azure-resources.bicep
   ```

---

## 4. Azure 権限問題

### 症状

```
ERROR: The client 'xxx@example.com' with object id 'xxx' does not have authorization to perform action 'Microsoft.KeyVault/vaults/secrets/read'
```

または

```
ERROR: Insufficient privileges to complete the operation
```

### 原因

1. **Key Vault Secrets User ロールが付与されていない**
2. **Entra ID Application Administrator ロールがない**
3. **Azure Contributor ロールがない**

### 解決方法

#### Key Vault アクセス権限の付与

```bash
# 自分のオブジェクトIDを取得
MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Key Vault Secrets User ロールを付与
az role assignment create \
  --assignee $MY_OBJECT_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/{sub-id}/resourceGroups/myapp-dev-rg/providers/Microsoft.KeyVault/vaults/kv-myapp-dev
```

#### Entra ID Application Administrator ロールの付与

```bash
# Azure Portal で実施:
# 1. Entra ID → Roles and administrators
# 2. "Application Administrator" を検索
# 3. 自分を追加
```

#### Azure Contributor ロールの付与

```bash
# サブスクリプションレベルで付与
az role assignment create \
  --assignee $MY_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/{subscription-id}

# リソースグループレベルで付与
az role assignment create \
  --assignee $MY_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/{sub-id}/resourceGroups/myapp-dev-rg
```

### 教訓

1. **必要な権限を事前に確認**
   - Azure: Contributor
   - Entra ID: Application Administrator
   - Key Vault: Key Vault Secrets User

2. **権限エラーは Azure Portal で確認**
   - IAM (アクセス制御) でロール割り当てを確認

---

## 5. GitHub Actions ワークフロー失敗

### 症状

```
ERROR: AADSTS7000215: Invalid client secret provided
```

または

```
ERROR: Cannot find application with identifier 'xxx'
```

### 原因

1. **GitHub Secrets が正しく設定されていない**
2. **Azure Service Principal の認証情報が期限切れ**
3. **Entra ID アプリケーションが削除された**

### 解決方法

#### GitHub Secrets の確認

```bash
# GitHub CLI でシークレット一覧を確認
gh secret list

# シークレットを再設定
gh secret set AZURE_CLIENT_ID --body "<client-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
```

#### Service Principal の再作成

```bash
# Service Principal を作成
az ad sp create-for-rbac \
  --name "gh-actions-myapp" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# 出力をGitHub Secretsに設定
```

### 教訓

1. **GitHub Secrets は定期的に確認**
   - 特にService Principalの認証情報

2. **Federated Credentials (OIDC) を使用**
   - Client Secretの期限切れ問題を回避
   - [GitHub Actions OIDC 認証](https://learn.microsoft.com/azure/developer/github/connect-from-azure)

---

## 🔧 一般的なトラブルシューティング手順

### 1. ログの確認（最優先）

```bash
# App Serviceのリアルタイムログ
az webapp log tail --name myapp-dev --resource-group myapp-dev-rg

# 過去のログをダウンロード
az webapp log download --name myapp-dev --resource-group myapp-dev-rg --log-file logs.zip
```

### 2. App Serviceの状態確認

```bash
# アプリの状態
az webapp show --name myapp-dev --resource-group myapp-dev-rg --query "state"

# HTTPステータス確認
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://myapp-dev.azurewebsites.net
```

### 3. コンテナ内の調査

```bash
# SSHでコンテナに接続
az webapp ssh --name myapp-dev --resource-group myapp-dev-rg

# ファイルシステム確認
ls -la /app

# 環境変数確認
env | grep CLIENT
```

### 4. Key Vaultの確認

```bash
# シークレット一覧
az keyvault secret list --vault-name kv-myapp-dev -o table

# 特定のシークレット取得
az keyvault secret show --vault-name kv-myapp-dev --name client-id --query "value" -o tsv
```

### 5. CI/CDの確認

```bash
# 最新のワークフロー実行
gh run list --limit 5

# 特定のワークフロー詳細
gh run view <run-id>

# 失敗したログを確認
gh run view <run-id> --log-failed
```

---

## 📚 参考リンク

### Azure App Service
- [App Service診断](https://learn.microsoft.com/azure/app-service/overview-diagnostics)
- [コンテナログの有効化](https://learn.microsoft.com/azure/app-service/configure-custom-container#enable-diagnostic-logs)
- [Key Vault参照](https://learn.microsoft.com/azure/app-service/app-service-key-vault-references)

### Bicep
- [Bicep ドキュメント](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Bicep トラブルシューティング](https://learn.microsoft.com/azure/azure-resource-manager/bicep/troubleshoot)

### GitHub Actions
- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [Azure Login Action](https://github.com/Azure/login)
- [OIDC 認証](https://learn.microsoft.com/azure/developer/github/connect-from-azure)

---

**最終更新日**: 2025-10-19

**注意**: このドキュメントはプロジェクト固有のトラブルを追加して使用してください。

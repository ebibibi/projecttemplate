# Azure DevContainer Project Template

**Azure × DevContainer × AI エージェント開発のテンプレートリポジトリ**

このテンプレートは、Azure にデプロイする Web アプリケーションを DevContainer で開発するための、すぐに使える環境を提供します。毎回 Dockerfile やCI/CDパイプラインをゼロから書く手間を省き、ベストプラクティスに基づいた開発を開始できます。

## 🎯 このテンプレートの目的

- **Azure × DevContainer の統合環境** - Docker + VS Code + Azure CLI/PowerShell を含む完全な開発環境
- **GitHub Actions → Azure App Service の CI/CD** - コミットするだけで自動デプロイ
- **Azure Key Vault による設定管理** - ローカル/Azure の両方で統一した設定管理（`.env` 不要）
- **AI エージェント (Claude Code) 対応** - `CLAUDE.md` による開発ガイドライン
- **トラブルシューティング履歴** - よくある問題と解決策を蓄積

## ✨ 主な特徴

### 1. 完全な DevContainer 環境

- **Python 3.11 + Node.js 20** の両対応
- **Azure CLI, PowerShell, Bicep** - Azure リソース管理ツール
- **GitHub CLI** - GitHub Actions の操作
- **Zsh + fzf** - 快適なシェル環境
- **Claude Code (AI エージェント)** - AI による開発支援

### 2. CI/CD パイプライン（単一ファイル管理）

**`.github/workflows/deploy.yml`** - 3つのジョブで構成：

1. **Entra ID Application** - Azure AD アプリケーション登録
2. **Azure Resources** - Bicep による Infrastructure as Code
3. **Build & Deploy** - Docker イメージビルド → ACR → App Service

### 3. Azure Key Vault による設定管理

- ❌ **`.env` ファイルは使用しません**
- ✅ ローカル開発でも Azure でも **Key Vault を参照**
- ✅ 設定変更は Key Vault で一元管理

### 4. AI エージェント開発ガイドライン

**`CLAUDE.md`** - Claude Code (AI エージェント) への開発指示：

- CI/CD ワークフローは単一ファイル
- タスク実装前に現在の状態を確認
- Microsoft Learn を最優先で参照
- Bicep 優先、スクリプト最小限
- Key Vault 必須（.env 禁止）
- 冪等性の徹底
- ローカルサーバー管理（複数起動禁止）

## 📁 ファイル構成

```
.
├── .devcontainer/
│   └── devcontainer.json          # DevContainer 設定
├── .github/
│   └── workflows/
│       └── deploy.yml             # CI/CD パイプライン (唯一のワークフロー)
├── infra/
│   ├── azure-resources.bicep      # メインテンプレート
│   ├── key-vault.bicep            # Key Vault
│   ├── container-registry.bicep   # Azure Container Registry
│   ├── app-service-container.bicep # App Service
│   ├── openai.bicep               # Azure OpenAI (オプション)
│   ├── postgresql.bicep           # PostgreSQL (オプション)
│   └── README.md                  # インフラセットアップ手順
├── Dockerfile                     # DevContainer 環境定義
├── CLAUDE.md                      # AI エージェント開発ガイドライン
├── TroubleshootHistory.md         # トラブルシューティング履歴
├── .gitignore                     # Git 除外設定
└── README.md                      # このファイル
```

## 🚀 クイックスタート

### 1. このテンプレートから新規リポジトリ作成

```bash
# GitHub CLI を使用
gh repo create my-new-project --template your-org/projecttemplate --private

# または GitHub Web UI から
# "Use this template" → "Create a new repository"
```

### 2. プロジェクト名を変更

#### `infra/azure-resources.bicep`
```bicep
// TODO: プロジェクト名を変更してください
var appName = 'my-new-project'
```

#### `.github/workflows/deploy.yml`
```yaml
env:
  REGISTRY_NAME: mynewproject${{ github.event.inputs.environment || 'dev' }}
  APP_NAME: my-new-project-${{ github.event.inputs.environment || 'dev' }}
  IMAGE_NAME: my-new-project-web
```

### 3. GitHub Actions シークレットを設定

Azure でサービスプリンシパルを作成し、GitHub Actions に登録します：

```bash
# Azure CLI で Federated Credential を使用したサービスプリンシパル作成
az ad sp create-for-rbac \
  --name "gh-actions-my-new-project" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# GitHub リポジトリにシークレットを設定
gh secret set AZURE_CLIENT_ID --body "<client-id>"
gh secret set AZURE_TENANT_ID --body "<tenant-id>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<subscription-id>"
```

詳細は [GitHub Actions OIDC 認証](https://learn.microsoft.com/azure/developer/github/connect-from-azure) を参照。

### 4. デプロイ

```bash
# GitHub Actions ワークフローを実行
gh workflow run deploy.yml --ref main

# または GitHub Web UI から
# "Actions" → "Deploy" → "Run workflow"
```

### 5. DevContainer で開発開始

1. VS Code で `Remote - Containers` 拡張機能をインストール
2. `F1` → `Remote-Containers: Reopen in Container`
3. コンテナ内で開発開始

```bash
# Azure CLI でログイン（Key Vault アクセスに必要）
az login

# アプリケーション起動（設定は自動的に Key Vault から読み込まれる）
cd src/web
python app.py
```

## ✅ 前提条件

### ローカル開発
- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Remote - Containers 拡張機能](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Azure 環境
- Azure サブスクリプション
- Azure CLI (`az login` で認証済み)
- 以下の権限：
  - **Azure**: Contributor ロール
  - **Entra ID**: Application Administrator ロール（Entra ID アプリ作成時）

## 🔑 Key Vault による設定管理（必須）

このテンプレートでは `.env` ファイルを使用せず、すべての設定を **Azure Key Vault** で管理します。

### ローカル開発での Key Vault アクセス

```bash
# 1. Azure CLI でログイン
az login

# 2. Key Vault Secrets User ロールを自分に付与
MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --assignee $MY_OBJECT_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/{sub-id}/resourceGroups/my-new-project-dev-rg/providers/Microsoft.KeyVault/vaults/kv-my-new-project-dev
```

### アプリケーションでの Key Vault 読み込み

```python
# Python 例
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# ローカル: az login で認証
# Azure App Service: Managed Identity で自動認証
credential = DefaultAzureCredential()

client = SecretClient(
    vault_url="https://kv-my-new-project-dev.vault.azure.net/",
    credential=credential
)

client_id = client.get_secret("client-id").value
client_secret = client.get_secret("client-secret-dev").value
```

## 📚 ベストプラクティス

### 1. CI/CD ワークフローは単一ファイルで管理

- ✅ `.github/workflows/deploy.yml` のみ
- ❌ 個別のワークフローファイルは作成しない
- ✅ 3つのジョブで管理（Entra ID → Azure Resources → Build & Deploy）

### 2. Bicep を優先、スクリプトは最小限

- ✅ リソース作成は Bicep で宣言的に管理
- ✅ スクリプトは Bicep で取得できない値のみ（Client Secret, API Key等）
- ✅ 冪等性を保つ（何度実行しても同じ結果）

### 3. Key Vault で設定を一元管理

- ❌ `.env` ファイルは使用しない
- ✅ すべてのシークレットを Key Vault に保存
- ✅ ローカルでも Azure でも Key Vault を参照

### 4. タスク実装前に現在の状態を確認

- ✅ ドキュメントを読む（design.md, tasks.md）
- ✅ Azure の既存リソースを確認（`az` コマンド）
- ✅ GitHub の既存ワークフローを確認
- ✅ ローカルファイルシステムを確認

**結論: ドキュメントは嘘をつくことがあるが、Azure CLI の出力は嘘をつかない。**

### 5. Microsoft Learn を最優先で参照

- ✅ WebSearch: `[操作内容] site:learn.microsoft.com 2024`
- ✅ WebFetch: 公式ドキュメントページを取得
- ❌ 記憶や推測でコードを書かない

### 6. ローカル開発サーバーは単一インスタンスのみ

- ❌ 複数サーバーの同時起動を禁止
- ✅ サーバー起動前に既存プロセスを確認・停止
- ✅ Flask/Node.js の自動リロード機能を活用
- ✅ 環境変数変更時のみ手動再起動

## 🔧 カスタマイズ

### Azure OpenAI を使用する場合

`infra/azure-resources.bicep` の OpenAI セクションのコメントを外してください。

詳細は [`infra/README.md`](infra/README.md) を参照。

### PostgreSQL を使用する場合

`infra/azure-resources.bicep` の PostgreSQL セクションのコメントを外してください。

詳細は [`infra/README.md`](infra/README.md) を参照。

### Python パッケージの追加

`Dockerfile` に追加してください：

```dockerfile
# Python パッケージをインストール（root で）
USER root
RUN pip3 install --break-system-packages <package-name>

# または requirements.txt を使用
COPY requirements.txt /tmp/
RUN pip3 install --break-system-packages -r /tmp/requirements.txt
```

## 🔍 トラブルシューティング

**🔴🔴🔴 重要: トラブル発生時は必ず [`TroubleshootHistory.md`](TroubleshootHistory.md) を最初に参照してください。**

過去に発生した問題とその解決方法を詳細に記録しています：

1. **Key Vault からの設定読み込み失敗**
2. **App Service が最新のコンテナを使用しない問題**
3. **Bicep デプロイエラー**
4. **Azure 権限問題**

## 📖 詳細ドキュメント

- [`CLAUDE.md`](CLAUDE.md) - AI エージェント開発ガイドライン
- [`infra/README.md`](infra/README.md) - インフラセットアップ詳細
- [`TroubleshootHistory.md`](TroubleshootHistory.md) - トラブルシューティング履歴

## 🌐 参考リンク

### Azure
- [Azure CLI リファレンス](https://learn.microsoft.com/cli/azure/)
- [Bicep 言語リファレンス](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/)

### DevContainers
- [Dev Containers](https://containers.dev/)
- [VS Code Remote - Containers](https://code.visualstudio.com/docs/devcontainers/containers)

### GitHub Actions
- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [Azure Login Action](https://github.com/Azure/login)
- [Docker Build & Push Action](https://github.com/docker/build-push-action)

## 📝 ライセンス

このテンプレートは自由に使用・改変できます。

---

**最終更新日**: 2025-10-19

**作成者**: Claude (AI Assistant)

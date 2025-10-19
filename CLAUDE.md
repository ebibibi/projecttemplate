# CLAUDE.md - AI Assistant Context

このファイルは、Claude（AI開発アシスタント）が Azure DevContainer プロジェクトの開発を支援する際のコンテキスト情報を提供します。

## 🔴🔴🔴 最重要原則

### 1. CI/CDワークフローは単一ファイルで管理（絶対厳守）

**❌ 絶対禁止**: 個別のワークフローファイルを作成すること

#### 実装前の必須確認

1. **既存のワークフローファイルを確認**
   ```bash
   ls -la .github/workflows/*.yml
   # deploy.yml のみがあるべき
   ```

#### 許可されるワークフローファイル

✅ `.github/workflows/deploy.yml` - **唯一の統合ワークフロー**（3つのジョブ）
  - Job 1: deploy-entra-id（Entra ID管理）
  - Job 2: deploy-azure-resources（Bicepデプロイ + Key Vault設定）
  - Job 3: build-and-deploy-app（Docker + App Service）

❌ その他の個別ワークフローは**絶対禁止**

---

### 2. タスク実装前に「現在の状態」を必ず確認する（最優先）

**新しいタスクを開始する前に、必ず以下の順序で現在の状態を確認してください。**

#### 必須確認手順

1. **ドキュメントを読む**
   - プロジェクトのREADME.md
   - infra/README.md

2. **Azureの既存リソースを確認する**
   ```bash
   # リソースグループ一覧
   az group list -o table

   # Web App一覧
   az webapp list -o table

   # Container Registry一覧
   az acr list -o table
   ```

3. **GitHubの既存ワークフローを確認する**
   ```bash
   find .github/workflows -name "*.yml"
   ```

4. **ローカルファイルシステムを確認する**
   ```bash
   ls -la infra/ .github/workflows/ src/
   ```

#### 重要な教訓

**結論: ドキュメントは嘘をつくことがあるが、Azure CLIの出力は嘘をつかない。**

---

### 3. Microsoft / Azure 関連作業の必須手順

**Microsoft関連作業を行う場合、必ず以下の手順を守ってください：**

1. **必ず Microsoft Learn を最初に参照する**
   - WebSearch: `[操作内容] site:learn.microsoft.com 2024`
   - WebFetch: 公式ドキュメントページを取得

2. **実装前のチェックリスト**
   - [ ] Microsoft Learn で最新の構文を確認したか？
   - [ ] サンプルコードを参照したか？
   - [ ] 非推奨の機能を使用していないか？

**❌ 禁止事項:**
- Microsoft Learn を参照せずに記憶や推測でコードを書く
- 古いブログ記事や Stack Overflow のみを参照する

---

### 4. Bicep を優先、スクリプトは最小限に（必須）

**重要：インフラ構築は Bicep を最優先で使用してください。**

#### 原則

1. **Bicep ファイルでできることは必ず Bicep で実装**
   - リソース作成、更新、削除
   - 環境変数設定
   - すべて Bicep で宣言的に管理

2. **スクリプトは Bicep で実現できない場合のみ使用**
   - Client Secret の生成と取得（Bicep では取得不可）
   - Azure OpenAI API Key の取得（Bicep では取得不可）
   - 動的な値の取得や複雑なロジック

3. **重複の禁止**
   - ❌ スクリプトと Bicep で同じリソースを作成
   - ✅ Bicep で作成、スクリプトは Bicep の出力を利用

#### 実装ガイドライン

```bicep
// ✅ 正しい：Bicep でリソース作成
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
  }
}
```

```powershell
# ✅ 正しい：スクリプトは Bicep で取得できない値のみ取得
$clientSecret = az rest --method POST --uri "https://graph.microsoft.com/v1.0/applications/$objectId/addPassword" ...
$openaiApiKey = az cognitiveservices account keys list --name $openaiName ...
```

```bash
# ❌ 間違い：スクリプトでリソース作成（Bicep でできることをスクリプトでやらない）
az keyvault create --name "kv-myapp" --resource-group "myapp-rg"
```

---

### 5. Bicep デプロイには Azure PowerShell を使用する（必須）

**重要：Azure CLI (`az deployment group create`) には既知のバグがあります。**

```powershell
# ✅ 正しい方法：Azure PowerShell
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-name" `
  -TemplateFile "template.bicep" `
  -TemplateParameterObject @{ param1 = "value1" }
```

```bash
# ❌ 禁止：Azure CLI（バグあり）
az deployment group create --template-file template.bicep
```

**GitHub Actions**:
```yaml
- uses: azure/login@v1
  with:
    enable-AzPSSession: true  # 必須

- uses: azure/powershell@v2
  with:
    azPSVersion: 'latest'
    inlineScript: |
      New-AzResourceGroupDeployment ...
```

---

### 6. 公式サンプルを必ず参照してそのまねをする

**新しい機能やライブラリを使用する場合、必ず公式サンプルを参照してください。**

#### 原則

1. **公式サンプルリポジトリを最初に探す**
   - Microsoft: [Azure-Samples](https://github.com/Azure-Samples)
   - Python: [python/cpython](https://github.com/python/cpython)

2. **サンプルをクローンして直接確認**
   ```bash
   git clone https://github.com/Azure-Samples/ms-identity-python-webapp.git
   cd ms-identity-python-webapp
   cat requirements.txt app.py
   ```

3. **サンプルのパターンを完全にコピー**
   - import文、初期化コード、設定ファイル形式
   - エラーハンドリング

#### 実装フロー

1. WebSearch: `[ライブラリ名] [機能] official sample github 2024`
2. サンプルリポジトリをクローン
3. 主要ファイルを読む（README.md, requirements.txt, app.py）
4. サンプルのパターンを自プロジェクトにコピー
5. 必要に応じてカスタマイズ（**コアパターンは変えない**）

#### なぜ重要か

- ✅ ベストプラクティス、動作保証、エッジケース対応、セキュリティ
- ❌ 自己流実装は、エッジケースや権限問題でハマる

---

### 7. 冪等性（べきとうせい）の徹底

**すべての設定変更・リソース作成は、必ずスクリプトファイル経由で行ってください。**

#### 原則

1. **❌ アドホックなコマンド実行の禁止**
   ```bash
   # ❌ ダメな例：直接 az コマンドで変更
   az webapp config appsettings set --name myapp --settings KEY=VALUE
   ```

2. **✅ 必ずスクリプトファイルに記載して実行**
   ```bash
   # ✅ 良い例：スクリプトファイルに記載
   ./infra/deploy.sh
   ```

3. **✅ スクリプトは冪等性を保つ**
   - 何度実行しても同じ結果
   - 既存リソースをチェックして、なければ作成、あれば更新

#### なぜ冪等性が重要か

1. **再現性**: 誰でも、いつでも、同じ環境を構築できる
2. **トレーサビリティ**: Git 履歴で追跡できる
3. **レビュー可能**: Pull Request でレビューできる
4. **ロールバック可能**: 前のバージョンに戻せる

---

### 8. Git コミット・プッシュの必須化

**各タスク完了後、必ず git commit と git push を実行してください。**

#### タスク完了の定義

- 動作確認が完了
- ドキュメント更新が完了
- → この時点で git commit + git push

#### コミット手順

```bash
# 1. 変更ファイルの確認
git status

# 2. ステージング
git add <files>

# 3. コミット（Conventional Commits形式）
git commit -m "<type>(<scope>): <subject>"

# 4. プッシュ
git push origin main
```

#### コミットメッセージ形式

```
<type>(<scope>): <subject>

タイプ:
- feat: 新機能
- fix: バグ修正
- refactor: リファクタリング
- docs: ドキュメント
- test: テスト追加・修正
- chore: ビルド、設定等
```

---

### 9. ローカル開発サーバーの管理（必須）

**アプリケーションの開発時は、必ず単一のサーバーインスタンスのみを起動してください。**

#### 原則

1. **❌ 複数サーバーの同時起動を禁止**
   - 複数のサーバーが起動していると、古いコードが動作し続ける
   - ポートの競合やコードの不整合が発生する

2. **✅ サーバー起動前に既存プロセスを確認・停止**
   ```bash
   # 実行中のバックグラウンドプロセスを確認
   # Claude Code では /bashes コマンドまたは BashOutput ツールで確認

   # 古いサーバーを停止してから新しいサーバーを起動
   # KillShell ツールで停止
   ```

3. **✅ デバッグモードの自動リロード機能**
   - Flask/Node.js 開発サーバーは自動リロード機能が有効
   - ソースファイル (`.py`, `.js`) の変更を検知して**自動的に再起動**

#### 自動リロードが有効な変更

以下のファイルを変更すると、サーバーが**自動的に再起動**します：

- ✅ `*.py` / `*.js` - すべてのソースファイル
- ✅ `templates/*.html` - テンプレート
- ✅ `static/*` - 静的ファイル（CSS, JS）

**手動再起動は不要です！**

#### 自動リロードが無効な変更（手動再起動が必要）

以下の変更は**手動再起動が必要**です：

- ❌ 環境変数の変更
- ❌ `requirements.txt` / `package.json` の変更（新しいライブラリのインストール）
- ❌ システムパッケージの変更（`apt install` など）

これらの場合は、サーバーを手動で再起動してください。

---

### 10. Key Vault による設定管理（必須）

**🔴🔴🔴 重要: `.env` ファイルは絶対に使用しません。すべての設定は Azure Key Vault で管理します。**

#### 原則

1. **❌ `.env` ファイルの使用を禁止**
   - ローカル開発でも Azure でも Key Vault を参照
   - 設定の重複・不整合を防ぐ

2. **✅ ローカル開発での Key Vault アクセス**
   ```bash
   # Azure CLI でログイン
   az login

   # Key Vault Secrets User ロールを自分に付与
   MY_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
   az role assignment create \
     --assignee $MY_OBJECT_ID \
     --role "Key Vault Secrets User" \
     --scope /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.KeyVault/vaults/{kv-name}
   ```

3. **✅ アプリケーションでの Key Vault 読み込み**
   ```python
   from azure.identity import DefaultAzureCredential
   from azure.keyvault.secrets import SecretClient

   # ローカル: az login で認証
   # Azure App Service: Managed Identity で自動認証
   credential = DefaultAzureCredential()
   client = SecretClient(vault_url="https://kv-myapp-dev.vault.azure.net/", credential=credential)

   client_id = client.get_secret("client-id").value
   client_secret = client.get_secret("client-secret-dev").value
   ```

#### なぜ Key Vault が必須か

1. **統一性**: ローカルでも Azure でも同じ設定を参照
2. **セキュリティ**: シークレットが Git に含まれない
3. **一元管理**: 設定変更は Key Vault で一箇所のみ
4. **監査**: Key Vault アクセスログで追跡可能

---

### 11. タスク完了後のCI/CD確認（絶対厳守）

**タスク完了後、必ずGitHub ActionsのCI/CDパイプラインが成功していることを確認してからユーザーに報告してください。**

#### 必須確認手順

1. **GitHub Actionsのステータス確認**
   ```bash
   # 最新のワークフロー実行状況を確認
   gh run list --limit 5

   # 最新のワークフローの詳細を確認
   gh run view
   ```

2. **失敗時の対応**
   ```bash
   # ログを確認
   gh run view --log-failed

   # または特定のrun IDでログ確認
   gh run view <run-id> --log
   ```

3. **修正後の再確認**
   - 修正をコミット・プッシュ
   - 再度 `gh run list` でステータス確認
   - すべてのジョブが✅成功するまで繰り返す

4. **Azureデプロイの確認**
   ```bash
   # Web Appの状態確認
   az webapp list --query "[].{Name:name, State:state, URL:defaultHostName}" -o table

   # HTTPステータス確認
   curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://myapp-dev.azurewebsites.net
   ```

#### ユーザー報告時の必須項目

タスク完了を報告する際は、以下を必ず含めてください：

```
✅ タスク完了報告

**実装内容:**
- [実装した機能1]
- [実装した機能2]

**CI/CD確認:**
✅ GitHub Actions: すべて成功
✅ Azure デプロイ: 完了
✅ HTTP Status: 200 OK

**本番URL:**
https://myapp-dev.azurewebsites.net

**次のステップ:**
[次に進むタスクまたは確認事項]
```

#### 禁止事項

- ❌ CI/CDが失敗している状態でタスク完了報告をする
- ❌ Azureデプロイを確認せずに報告する
- ❌ 「たぶん動いているはず」で報告する

#### 必須事項

- ✅ GitHub Actionsが全て✅成功していることを確認
- ✅ Azure Web AppがRunning状態であることを確認
- ✅ HTTPステータスが200 OKであることを確認
- ✅ すべて確認してからユーザーに報告

**結論: 「きちんと展開が成功するところまで確認してから報告する」ことを絶対に守る。**

---

## 開発ガイドライン

### 技術スタック

#### バックエンド
- **Python 3.11+** または **Node.js 20+**
- **Azure Functions** / **FastAPI** / **Flask** / **Express.js**

#### フロントエンド（オプション）
- **React + TypeScript**
- **Vue.js + TypeScript**
- **Next.js**

#### インフラ
- **Azure**（必須）
- **Bicep**（優先）
- **GitHub Actions**（単一ワークフロー）
- **Microsoft Entra ID**（認証）

### コーディング規約

#### Python

```python
# 命名規則
- クラス: PascalCase
- 関数/変数: snake_case
- 定数: UPPER_SNAKE_CASE

# 型ヒント
from typing import Optional, List, Dict

def process_data(data: str, limit: int = 10) -> Optional[Dict[str, Any]]:
    """データを処理します。"""
    ...
```

#### TypeScript

```typescript
// 命名規則
- クラス: PascalCase
- 関数/変数: camelCase
- 定数: UPPER_SNAKE_CASE
- インターフェース: PascalCase

// 型安全性
- `any` の使用は最小限に
- すべての関数に戻り値の型を明示
```

---

## AIアシスタント（Claude）への指示

### コード生成時の必須手順

**実装開始前:**
1. **プロジェクトのドキュメントを読む**: README.md, infra/README.md
2. **公式サンプル参照**: Microsoft Learn, GitHub サンプルリポジトリ
3. **設計の明確化**: ドキュメントが不明確な場合、先に明確化

**実装中:**
4. ドキュメントの設計に従う
5. 型安全性（TypeScript, Python 型ヒント）
6. セキュリティ（機密情報のハードコーディング禁止）
7. エラーハンドリング

**実装後:**
8. テストコード生成
9. ドキュメント（複雑なロジックにコメント）
10. CI/CD確認（必須）

---

### 動作確認とCI/CD検証（必須）

**各タスク完了時の必須手順：**

1. **CI/CDパイプライン確認**
   ```bash
   gh run list --limit 5
   gh run view
   ```
   - ✅ すべてのワークフローが成功していることを確認
   - ❌ 失敗している場合は、原因を調査・修正してから次に進む

2. **ローカル動作確認**
   - ✅ アプリが起動
   - ✅ 正常動作

3. **Azure環境への反映確認**
   - ✅ Azure Portal で該当リソースが作成されている
   - ✅ デプロイされたアプリが正常動作
   - ✅ ログに異常がない

**🚨 重要な原則:**
- **CI/CDが失敗している状態で次のタスクに進まない**
- **ユーザー確認なしに大きな変更を続けない**

---

## トラブルシューティング

**🔴🔴🔴 重要: トラブル発生時は必ず `TroubleshootHistory.md` を最初に参照してください。**

過去に発生した問題とその解決方法を詳細に記録しています：

このドキュメントには以下の情報が含まれています：
1. **問題の症状と原因**
2. **調査手順**（実際に実行したコマンド）
3. **解決方法**（具体的な修正内容）
4. **学んだ教訓**（同じ問題を防ぐための対策）

---

## 参考リンク

### Azure
- [Azure CLI リファレンス](https://learn.microsoft.com/cli/azure/)
- [Bicep 言語リファレンス](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/)
- [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/)

### GitHub Actions
- [GitHub Actions ドキュメント](https://docs.github.com/actions)
- [Azure Login Action](https://github.com/Azure/login)

---

**最終更新日**: 2025-10-19

このプロジェクトは、Azure × DevContainer × AI エージェント開発のテンプレートです。
セキュリティとベストプラクティスを最優先に、効率的な開発を実現しましょう！

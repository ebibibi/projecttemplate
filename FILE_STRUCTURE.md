# Project File Structure

This document describes the file structure of the Azure DevContainer Project Template.

## 📁 Root Directory

```
.
├── .devcontainer/
│   └── devcontainer.json           # VS Code DevContainer settings
├── .github/
│   └── workflows/
│       ├── deploy.yml              # CI/CD pipeline (simplified template)
│       └── deploy.yml.example      # Full example with 3 jobs (reference)
├── infra/
│   ├── azure-resources.bicep       # Main Bicep template
│   ├── key-vault.bicep             # Azure Key Vault
│   ├── container-registry.bicep    # Azure Container Registry
│   ├── app-service-container.bicep # App Service (Linux Container)
│   ├── openai.bicep                # Azure OpenAI (optional)
│   ├── postgresql.bicep            # PostgreSQL (optional)
│   ├── bicepconfig.json            # Bicep compiler settings
│   └── README.md                   # Infrastructure setup guide
├── .gitignore                      # Git ignore patterns
├── CLAUDE.md                       # AI agent development guidelines
├── Dockerfile                      # DevContainer environment
├── README.md                       # Project overview
├── TroubleshootHistory.md          # Troubleshooting history
└── FILE_STRUCTURE.md               # This file
```

## 📝 File Descriptions

### Configuration Files

| File | Purpose | Required |
|------|---------|----------|
| `.devcontainer/devcontainer.json` | VS Code DevContainer settings | ✅ |
| `.gitignore` | Files to exclude from Git | ✅ |
| `infra/bicepconfig.json` | Bicep compiler settings | ✅ |

### Infrastructure Files

| File | Purpose | Required |
|------|---------|----------|
| `infra/azure-resources.bicep` | Main Bicep template (subscription scope) | ✅ |
| `infra/key-vault.bicep` | Azure Key Vault module | ✅ |
| `infra/container-registry.bicep` | Azure Container Registry module | ✅ |
| `infra/app-service-container.bicep` | App Service module | ✅ |
| `infra/openai.bicep` | Azure OpenAI module (optional) | ⚙️ |
| `infra/postgresql.bicep` | PostgreSQL module (optional) | ⚙️ |

### CI/CD Files

| File | Purpose | Required |
|------|---------|----------|
| `.github/workflows/deploy.yml` | Simplified CI/CD template | ✅ |
| `.github/workflows/deploy.yml.example` | Full example (reference) | 📚 |

### Documentation Files

| File | Purpose | Required |
|------|---------|----------|
| `README.md` | Project overview and quick start | ✅ |
| `CLAUDE.md` | AI agent development guidelines | ✅ |
| `TroubleshootHistory.md` | Troubleshooting history | ✅ |
| `infra/README.md` | Infrastructure setup guide | ✅ |
| `FILE_STRUCTURE.md` | This file | 📚 |

### DevContainer Files

| File | Purpose | Required |
|------|---------|----------|
| `Dockerfile` | DevContainer environment definition | ✅ |

## 🚀 Getting Started

1. **Customize project name:**
   - `infra/azure-resources.bicep`: `var appName = 'your-project-name'`
   - `.github/workflows/deploy.yml`: `REGISTRY_NAME`, `APP_NAME`, `IMAGE_NAME`

2. **Review and enable optional features:**
   - Azure OpenAI: Uncomment in `infra/azure-resources.bicep`
   - PostgreSQL: Uncomment in `infra/azure-resources.bicep`

3. **Add project-specific files:**
   - `src/`: Source code
   - `tests/`: Test code
   - `requirements.txt` or `package.json`: Dependencies

4. **Deploy:**
   - Set up GitHub Secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)
   - Push to `main` branch to trigger CI/CD

## 📚 Reference

For detailed documentation, see:
- [README.md](README.md) - Project overview
- [CLAUDE.md](CLAUDE.md) - AI agent guidelines
- [infra/README.md](infra/README.md) - Infrastructure setup
- [TroubleshootHistory.md](TroubleshootHistory.md) - Troubleshooting
- [.github/workflows/deploy.yml.example](.github/workflows/deploy.yml.example) - Full CI/CD example

---

**Last Updated:** 2025-10-19

# syntax=docker/dockerfile:1.6

# ============================================================================
# Azure DevContainer Project Template - Dockerfile
# ============================================================================
#
# このDockerfileは、Azure × DevContainer × AI エージェント開発のための
# 完全な開発環境を提供します。
#
# 含まれるツール:
# - Python 3.11 + Node.js 20
# - Azure CLI, PowerShell, Bicep
# - GitHub CLI
# - Azure Functions Core Tools, Azurite
# - kubectl, helm, azcopy, azd
# - Zsh + fzf (快適なシェル)
# - Claude Code (AI エージェント)
#
# カスタマイズ:
# - プロジェクト固有のパッケージは各セクションの TODO コメントで追加
#
# ============================================================================

ARG NODE_VERSION=20
# Use specific tag to avoid cache issues
FROM node:20.18.1-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ===== Base packages & QoL =====
ARG ZSH_IN_DOCKER_VERSION=1.2.0
ARG GIT_DELTA_VERSION=0.18.2
ARG CLAUDE_CODE_VERSION=latest

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates apt-transport-https curl wget unzip zip \
  git less vim nano jq procps gnupg2 lsb-release \
  iptables ipset iproute2 dnsutils fzf zsh man-db aggregate \
  python3 python3-pip software-properties-common locales \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i -e 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# git-delta (快適diff)
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" -O /tmp/delta.deb && \
  dpkg -i /tmp/delta.deb && rm /tmp/delta.deb

# 作業DIR / history永続化
ARG USERNAME=node
RUN mkdir -p /workspace /home/node/.claude /commandhistory && \
  touch /commandhistory/.bash_history && \
  chown -R ${USERNAME}:${USERNAME} /workspace /home/node/.claude /commandhistory
WORKDIR /workspace
ENV DEVCONTAINER=true

# npm グローバル用ディレクトリ
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Zsh & fzf（Nodeユーザーに適用）
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" -x
ENV SHELL=/bin/zsh EDITOR=nano VISUAL=nano

# ===== Claude Code (Nodeユーザーで) =====
USER node
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} typescript

# ===== ここから Azure / DevOps 系ツールは root で導入 =====
USER root

# GitHub CLI（公式レポジトリ）
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list && \
  apt-get update && apt-get install -y --no-install-recommends gh && \
  rm -rf /var/lib/apt/lists/*

# Azure CLI（Microsoft公式レポジトリ）
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg && \
  echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/azure-cli.list && \
  apt-get update && apt-get install -y --no-install-recommends azure-cli && \
  rm -rf /var/lib/apt/lists/*

# PowerShell 7 + Az Module
RUN wget -q "https://packages.microsoft.com/config/debian/$(lsb_release -rs)/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb && \
  dpkg -i /tmp/packages-microsoft-prod.deb && rm /tmp/packages-microsoft-prod.deb && \
  apt-get update && apt-get install -y --no-install-recommends powershell && \
  rm -rf /var/lib/apt/lists/*
RUN pwsh -NoLogo -NonInteractive -Command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name Az -Scope AllUsers -Force"

# Bicep CLI
ARG BICEP_URI=https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
RUN curl -Lo /usr/local/bin/bicep ${BICEP_URI} && chmod +x /usr/local/bin/bicep

# Azure Functions Core Tools / Azurite（npmは Nodeユーザーで）
USER node
RUN npm install -g azure-functions-core-tools@4 --unsafe-perm=true && \
  npm install -g azurite

# TODO: プロジェクト固有のnpmパッケージをここに追加
# RUN npm install -g <package-name>

# TODO: プロジェクト固有のPythonパッケージをここに追加（rootで実行）
# USER root
# RUN pip3 install --break-system-packages <package-name>
# または requirements.txt を使用
# COPY requirements.txt /tmp/
# RUN pip3 install --break-system-packages -r /tmp/requirements.txt

# Azure Dev CLI (azd) / kubectl / helm / azcopy（rootに戻す）
USER root
RUN curl -fsSL https://aka.ms/install-azd.sh | bash && \
  curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && chmod +x /usr/local/bin/kubectl && \
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash && \
  curl -fsSL https://aka.ms/downloadazcopy-v10-linux -o /tmp/azcopy.tgz && \
  tar -xzf /tmp/azcopy.tgz -C /tmp && \
  cp /tmp/azcopy_linux_amd64_*/azcopy /usr/local/bin/azcopy && chmod +x /usr/local/bin/azcopy && \
  rm -rf /tmp/azcopy*


# 仕上げ
USER node
CMD ["zsh"]

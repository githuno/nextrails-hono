#!/bin/bash
# =================================================================
# 🚀 postCreateCommand: ツール環境初期化
# =================================================================
# 実行タイミング：コンテナ作成時（一度だけ）
# 責務：mise インストール、ツール環境準備
# 
# 設定値・ボリューム管理は postAttachCommand (attachCommand.sh) に委譲
#
set -e

# ログ出力の設定
LOG_FILE="/tmp/devcontainer_create.log"
exec 1> >(tee -a "$LOG_FILE") 2>&1
echo "🎬 [$(date)] Development container creation started"

# 1. ワークスペースルートの特定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Docker volume にマウント済み（devcontainer.json で設定）
STORAGE_ROOT="$WORKSPACE_ROOT/.storage"
echo "📂 Workspace root: $WORKSPACE_ROOT"

# 2. 権限の修正 (ボリュームマウント領域の所有権を確保)
echo "👤 Adjusting storage permissions..."
sudo chown $(whoami):$(whoami) "$STORAGE_ROOT" 2>/dev/null || true

# 3. mise (Tool Version Manager) のセットアップ
if ! command -v mise &> /dev/null; then
    echo "📥 Installing mise..."
    curl https://mise.run | sh
fi

# 4. シェル設定の更新 (.bashrc)
if ! grep -q "mise activate bash" ~/.bashrc; then
    echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> ~/.bashrc
    echo "📝 Added mise activation to .bashrc"
fi

# 5. 全シェルが mise を認識するよう /etc/profile.d に設定を配置
sudo tee /etc/profile.d/mise-init.sh > /dev/null <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
  eval "$($HOME/.local/bin/mise activate sh)"
fi
EOF
sudo chmod 644 /etc/profile.d/mise-init.sh
echo "📝 Added mise activation to /etc/profile.d/mise-init.sh"

# 6. スクリプトの実行権限を確実に付与
chmod +x "$SCRIPT_DIR/attachCommand.sh"

# 7. ツールの事前インストール (.mise.toml に基づく)
echo "🛠️ Pre-installing tools via mise..."
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"
cd "$WORKSPACE_ROOT"
if [ -f ".mise.toml" ]; then
    mise trust 2>/dev/null || true
    mise install --yes
else
    echo "⚠️ .mise.toml not found in $WORKSPACE_ROOT"
fi

# 8. Git credential helper を gh に設定（PATやSSH不要でghコマンドによりgit操作を可能にする）
echo "🔐 Setting Git credential helper to gh..."
git config --global credential.helper gh

echo "✨ [$(date)] Development container creation completed"


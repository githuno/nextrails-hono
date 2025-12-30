#!/bin/bash

set -e

# WTP: https://www.notion.so/wtp-Git-CLI-DEV-2d9565e97d7c81fca7b1c2c1dd8792d4
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/satococoa/wtp/releases/latest \
  | jq -r '.assets[] | select(.name | test("Linux_x86_64")) | .browser_download_url')

FILENAME=$(basename "$DOWNLOAD_URL")

curl -L -o "$FILENAME" "$DOWNLOAD_URL"

tar xzf "$FILENAME"

rm "$FILENAME"

sudo mv wtp /usr/local/bin/

# Get START_DIR from .env.config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env.config" ]; then
  set -a
  source "$SCRIPT_DIR/.env.config"
  set +a
else
  echo "❌ .env.config not found"
  exit 1
fi

TARGET_DIR="${START_DIR:-.}"
cd "$TARGET_DIR"

# .wtp.ymlの作成
TEMPLATE_FILE="$SCRIPT_DIR/.wtp.template.yml"
if [ -f "$TEMPLATE_FILE" ]; then
    echo "Creating .wtp.yml from template..."
    
    # START_DIRの絶対パスを取得
    ABS_START_DIR=$(pwd)
    ABS_WTP_DIR="$ABS_START_DIR/.wtp"
    
    # wtpが設定ファイルを探す場所を特定
    # サブモジュールの場合、git-common-dirがリポジトリルートとみなされる
    COMMON_DIR=$(git rev-parse --git-common-dir)
    
    # COMMON_DIRが.gitで終わる場合はその親、そうでなければCOMMON_DIR自体をターゲットにする
    if [[ "$COMMON_DIR" == *".git" ]]; then
        CONFIG_DEST_DIR=$(dirname "$COMMON_DIR")
    else
        CONFIG_DEST_DIR="$COMMON_DIR"
    fi
    
    # テンプレートをコピーし、プレースホルダを置換
    # .wtp.ymlの実体はプロジェクトルート（START_DIR）に作成し、.git側からリンクを貼る
    REAL_CONFIG="$ABS_START_DIR/.wtp.yml"
    WORKSPACE_ROOT="/workspaces/hono"
    
    sed -e "s|base_dir: \".*\"|base_dir: \"$ABS_WTP_DIR\"|" \
        -e "s|PROJECT_ROOT_PLACEHOLDER|$ABS_START_DIR|g" \
        -e "s|REPO_ROOT_PLACEHOLDER|$WORKSPACE_ROOT|g" \
        "$TEMPLATE_FILE" > "$REAL_CONFIG"
    
    # .git側の設定ディレクトリにシンボリックリンクを作成
    ln -sfn "$REAL_CONFIG" "$CONFIG_DEST_DIR/.wtp.yml"
    
    echo "Config created at: $REAL_CONFIG"
    echo "Linked to: $CONFIG_DEST_DIR/.wtp.yml"
    echo "Worktrees will be created in: $ABS_WTP_DIR"
else
    echo "Template file not found: $TEMPLATE_FILE"
fi

# .gitignoreへの追記
if [ -f .gitignore ]; then
    if ! grep -q ".wtp/" .gitignore; then
        echo "Updating .gitignore..."
        echo -e "\n# Worktree Plus\n.wtp/\n.wtp*" >> .gitignore
    fi
else
    echo "❌ .gitignore not found"
fi


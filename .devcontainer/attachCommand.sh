#!/bin/bash
# ================================================================
# 🔗 postAttachCommand: 設定適用・ボリューム同期
# ================================================================
# 実行タイミング：コンテナアタッチ時（毎回）
# 責務：
#   1. .env.config を読み込み（VOLUME_TARGETS, START_DIR, 環境変数）
#   2. ボリューム永続化の初回セットアップ（.storage が存在しない場合のみ）
#   3. ボリューム同期とシンボリックリンク管理
#   4. 不要なストレージ削除
#   5. 環境変数を /etc/profile.d に登録
#
set -euo pipefail

LOG_FILE="/tmp/devcontainer_attach.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# ------------------------------------------------
# 基本パス
# ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# Docker volume にマウント済み（devcontainer.json で設定）
STORAGE_ROOT="$WORKSPACE_ROOT/.storage"

mkdir -p "$STORAGE_ROOT"

# ------------------------------------------------
# .env.config 読み込み（統合設定）
# ================================================
# - VOLUME_TARGETS: ボリューム永続化対象
# - START_DIR: アタッチ後の作業ディレクトリ
# - NODE_ENV, FRONTEND_URL, BACKEND_URL: アプリケーション環境変数
# ================================================
if [ -f "$SCRIPT_DIR/.env.config" ]; then
  set -a
  source "$SCRIPT_DIR/.env.config"
  set +a
else
  echo "❌ .env.config not found"
  exit 1
fi

# /etc/profile.d に登録（新しいシェル起動時に自動読み込み）
# ※ アタッチ時に毎回再生成することで、.env.config の変更を即座に反映
WORKSPACE_NAME="$(basename "$WORKSPACE_ROOT")"
sudo tee /etc/profile.d/devenv-global.sh > /dev/null <<ENVEOF
#!/bin/bash
# .devcontainer/.env.config のアプリケーション環境変数を全シェルで動的読み込み
# 毎回のアタッチで再生成されるため、変更が即座に反映される
if [ -f "/workspaces/$WORKSPACE_NAME/.devcontainer/.env.config" ]; then
  set -a
  source "/workspaces/$WORKSPACE_NAME/.devcontainer/.env.config"
  set +a
fi
ENVEOF
sudo chmod 644 /etc/profile.d/devenv-global.sh

# ------------------------------------------------
# mise
# ------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
  mise trust 2>/dev/null || true
  mise install --yes 2>/dev/null || true
fi

# ------------------------------------------------
# 不要なストレージを削除
# ------------------------------------------------
cleanup_stale_storage() {
  # 現在のVOLUME_TARGETSから有効なストレージ名リストを作成
  local valid_storages=()
  if [ -n "${VOLUME_TARGETS:-}" ]; then
    while IFS= read -r volume_target; do
      volume_target="$(echo "$volume_target" | xargs)"
      if [ -n "$volume_target" ]; then
        local storage_name="${volume_target//\//_}"
        valid_storages+=("$storage_name")
      fi
    done <<< "$VOLUME_TARGETS"
  fi

  # ストレージ内の全ディレクトリをチェック
  if [ -d "$STORAGE_ROOT" ]; then
    for storage_dir in "$STORAGE_ROOT"/*_node_modules; do
      if [ -d "$storage_dir" ]; then
        dir_name="$(basename "$storage_dir")"
        is_valid=false
        
        for valid_name in "${valid_storages[@]}"; do
          # valid_name には既に "_node_modules" が含まれている
          if [ "$dir_name" = "$valid_name" ]; then
            is_valid=true
            break
          fi
        done
        
        if [ "$is_valid" = false ]; then
          rm -rf "$storage_dir"
          rm -f "$STORAGE_ROOT/.hash_${dir_name%_node_modules}"
        fi
      fi
    done
  fi
}

# ------------------------------------------------
# npm sync（初回セットアップのみ）
# ------------------------------------------------
sync_volume() {
  local volume_target="$1"
  local project_dir="$WORKSPACE_ROOT/$(dirname "$volume_target")"
  local node_modules_link="$WORKSPACE_ROOT/$volume_target"

  local pkg_file="$project_dir/package.json"
  local lock_file="$project_dir/package-lock.json"
  local storage_name="${volume_target//\//_}"
  local storage_path="$STORAGE_ROOT/$storage_name"
  local storage_node_modules="$storage_path/node_modules"

  # 前提条件チェック
  if [ ! -f "$pkg_file" ] || [ ! -f "$lock_file" ]; then
    return 0
  fi

  # 判定: ストレージが既に存在するか（初回セットアップ判定）
  if [ ! -d "$storage_node_modules" ]; then
    # ストレージをセットアップ
    mkdir -p "$storage_path"

    # package.json と package-lock.json をストレージにコピー
    cp "$pkg_file" "$storage_path/package.json" || {
      echo "❌ Failed: copy $volume_target/package.json"
      return 1
    }
    cp "$lock_file" "$storage_path/package-lock.json" || {
      echo "❌ Failed: copy $volume_target/package-lock.json"
      return 1
    }

    # npm install を直接ストレージに実行
    if ! npm install --prefix="$storage_path" --no-audit --prefer-offline --no-save; then
      echo "❌ Failed: npm install $volume_target"
      return 1
    fi
  fi

  # シンボリックリンク確認と作成（毎回実行）
  if [ -L "$node_modules_link" ]; then
    # シンボリックリンク存在 → OK
    :
  elif [ -d "$node_modules_link" ]; then
    # ディレクトリ存在 → シンボリックリンク化
    rm -rf "$node_modules_link"
    local rel_target="../.storage/$storage_name/node_modules"
    ln -s "$rel_target" "$node_modules_link" || {
      echo "❌ Failed: symlink $volume_target"
      return 1
    }
  else
    # 何も存在しない → シンボリックリンク作成
    local rel_target="../.storage/$storage_name/node_modules"
    if ! ln -s "$rel_target" "$node_modules_link"; then
      echo "❌ Failed: symlink $volume_target"
      return 1
    fi
  fi
}

# ------------------------------------------------
# VOLUME_TARGETS
# ------------------------------------------------
cleanup_stale_storage

if [ -n "${VOLUME_TARGETS:-}" ]; then
  while IFS= read -r volume_target; do
    volume_target="$(echo "$volume_target" | xargs)"
    [ -n "$volume_target" ] && sync_volume "$volume_target"
  done <<< "$VOLUME_TARGETS"
fi

# ------------------------------------------------
# /usr/bin へのシンボリックリンク更新
# ================================================
# mise インストール後、新しいツールバージョンが追加された可能性があるため
# 毎回のアタッチで /usr/bin リンクを更新
# ================================================
echo "🔗 Updating mise tools in /usr/bin..."
MISE_INSTALLS="$HOME/.local/share/mise/installs"
for tool_dir in "$MISE_INSTALLS"/*; do
  if [ -d "$tool_dir" ]; then
    # バージョンディレクトリを走査
    for version_dir in "$tool_dir"/*; do
      if [ -d "$version_dir" ]; then
        # bin/ サブディレクトリがあればそこから、なければバージョンディレクトリ直下から探索
        if [ -d "$version_dir/bin" ]; then
          # 標準構造: tool/version/bin/*
          for bin_file in "$version_dir/bin"/*; do
            if [ -f "$bin_file" ] && [ -x "$bin_file" ]; then
              bin_name="$(basename "$bin_file")"
              sudo ln -sf "$bin_file" "/usr/bin/$bin_name" 2>/dev/null || true
            fi
          done
        else
          # mise のuv/node等の特殊構造: tool/version/*/bin または tool/version/*/* にバイナリ直置き
          for potential_bin_dir in "$version_dir"/*; do
            if [ -d "$potential_bin_dir" ]; then
              # さらに深い階層: tool/version/platform/bin/*
              if [ -d "$potential_bin_dir/bin" ]; then
                for bin_file in "$potential_bin_dir/bin"/*; do
                  if [ -f "$bin_file" ] && [ -x "$bin_file" ]; then
                    bin_name="$(basename "$bin_file")"
                    sudo ln -sf "$bin_file" "/usr/bin/$bin_name" 2>/dev/null || true
                  fi
                done
              fi
              # tool/version/platform/ 直下のバイナリ
              for bin_file in "$potential_bin_dir"/*; do
                if [ -f "$bin_file" ] && [ -x "$bin_file" ]; then
                  bin_name="$(basename "$bin_file")"
                  sudo ln -sf "$bin_file" "/usr/bin/$bin_name" 2>/dev/null || true
                fi
              done
            fi
          done
        fi
      fi
    done
  fi
done

# ------------------------------------------------
# START_DIR
# ------------------------------------------------
if [ -n "${START_DIR:-}" ]; then
  target="$WORKSPACE_ROOT/$START_DIR"
  if [ -d "$target" ]; then
    cd "$target"
  fi
fi

echo "✨ Ready"

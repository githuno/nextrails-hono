# .devcontainer ガイド

## 設定を変更するには

| やりたいこと         | ファイル                       | 変更反映       |
| -------------------- | ------------------------------ | -------------- |
| ツールバージョン     | `.mise.toml`                   | 次回アタッチ   |
| ボリューム永続化対象 | `.env.config` (VOLUME_TARGETS) | 次回アタッチ   |
| 作業ディレクトリ     | `.env.config` (START_DIR)      | 次回アタッチ   |
| アプリ環境変数       | `.env.config` (NODE_ENV など)  | 新シェル起動時 |

## ファイル構成

| ファイル            | 実行タイミング              | 責務                         |
| ------------------- | --------------------------- | ---------------------------- |
| `devcontainer.json` | コンテナ作成                | 構成・エントリーポイント     |
| `createCommand.sh`  | コンテナ作成時（一度）      | ツール環境初期化             |
| `attachCommand.sh`  | コンテナアタッチ時（毎回）  | 設定読み込み・ボリューム同期 |
| `.env.config`       | attachCommand で読み込み    | スクリプト + 環境変数設定    |
| `.mise.toml`        | createCommand/attachCommand | ツールバージョン             |

## .env.config パラメータ

```bash
# スクリプト処理パラメータ
VOLUME_TARGETS="
<project>/node_modules
"
START_DIR=<project>

# アプリケーション環境変数
NODE_ENV=<env>
FRONTEND_URL=<url>
BACKEND_URL=<url>
```

## よくある変更

### プロジェクトを追加

`.env.config` の `VOLUME_TARGETS` に追加：

```bash
VOLUME_TARGETS="
<project1>/node_modules
<project2>/node_modules    ← 追加
"
```

→ VS Code `Reopen in Container`

### ツールバージョン変更

`.mise.toml` で変更：

```toml
[tools]
node = "25"
```

→ 次回アタッチで自動適用

### 環境変数を切り替え

`.env.config` で変更：

```bash
NODE_ENV=staging
BACKEND_URL=https://api-staging.example.com
```

→ `bash -i` で新シェル起動後、即座に反映

## 処理フロー

```
1. コンテナ作成 → [postCreateCommand]
   createCommand.sh: ツール環境初期化

2. コンテナアタッチ → [postAttachCommand] (毎回)
   attachCommand.sh:
     a. .env.config 読み込み
     b. /etc/profile.d/devenv-global.sh 再生成
     c. ツール更新確認 (mise install --yes)
     d. ボリューム同期
        - 初回: npm install → .storage/{target}
        - 2回目以降: symlink のみ
     e. START_DIR に移動
```

## トラブル

| 症状                              | 対処                                             |
| --------------------------------- | ------------------------------------------------ |
| npm run dev 失敗                  | `rm -rf /workspaces/<project>/.storage` → Reopen |
| 環境変数が反映されない            | `bash -i` で新シェル起動                         |
| VOLUME_TARGETS 変更が反映されない | Reopen in Container                              |

## 設計原則

- **SSOT**: `.env.config` + `.mise.toml` が唯一の設定源
- **毎回同期**: `attachCommand.sh` は毎回実行、変更が即座に反映
- **初回のみ install**: `.storage` が存在しない場合のみ `npm install`
- **動的環境変数**: `/etc/profile.d/devenv-global.sh` を毎回再生成

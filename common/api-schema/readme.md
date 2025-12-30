https://developers.microad.co.jp/entry/2025/04/25/180000
(https://www.notion.so/1e3565e97d7c8101a3b0d93939bfe248)

# ディレクトリ作成

`mkdir -p common/api-schema`
`cd common/api-schema`
`npm init -y`

{
  "name": "@common/api-schema",
  "version": "0.1.0",
  "description": "API Schema for Radiko",
  "types": "types/index.ts",
  "scripts": {
    "preview-docs": "redocly preview-docs src/index.yaml",
    "bundle": "redocly bundle src/index.yaml -o output/openapi.yaml",
    "build-docs": "redocly build-docs src/index.yaml -o output/index.html",
    "lint": "redocly lint src/index.yaml",
    "generate:type": "openapi-typescript output/openapi.yaml --output types/schema.ts",
    "build": "npm run bundle && npm run generate:type && npm run build-docs"
  },
  "dependencies": {
    "type-fest": "*",
    "@redocly/cli": "*",
    "openapi-typescript": "*",
    "zod": "*",
    "openapi-zod-client": "*"
  }
}

`mkdir -p src output types`

# パッケージインストール

### 開発依存パッケージのインストール
`npm install -D typescript @types/node`

### API スキーマ関連パッケージのインストール
`npm install type-fest @redocly/cli openapi-typescript zod openapi-zod-client`

### TypeScriptの設定ファイル作成
`npx tsc --init`


# 管理方法
1. src/{対象}以下のYAML, paths.ts, zodスキーマを更新
2. （必要あれば、src/index.yamlや*-utils.tsを更新）
3. `npm run build`

`import { createResponseSchema } from "@common/api-schema/src/zod-utils";`

#### フロントエンドでの使用例：
```
import { createResponseSchema } from '@common/api-schema';

export const useApi = async <
  Path extends ApiPath,
  Method extends ExtractHttpMethod<Path>
>(
  path: Path,
  method: Method,
  params?: ApiParams<Path, Method>
) => {
  const response = await $fetch(path, {
    method,
    ...params,
  });

  const schema = createResponseSchema<Path, Method>();
  return schema.parse(response);
};
```

#### バックエンド側での使用例：
```
import { AuthResponseSchema } from '@common/api-schema';

@Post('/radiko/auth')
async auth(@Query('ip') ip?: string) {
  const response = {
    token: 'xxx',
    areaId: 'JP13',
    success: true,
  };

  return AuthResponseSchema.parse(response);
}
```


---


フロントエンドとバックエンドを別リポジトリでデプロイする場合、以下の方法を推奨します：

1. npmパッケージとして公開する方法
api-schemaをnpmパッケージとして公開:

```
{
  "name": "@your-org/api-schema",
  "version": "1.0.0",
  "private": true,
  "files": [
    "dist",
    "src"
  ],
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    // ...existing scripts...
    "build": "tsc",
    "prepublishOnly": "npm run build"
  }
}
```

プライベートリポジトリとして公開:`npm publish --access private`

各プロジェクトでインストール:`npm install @your-org/api-schema`

2. Git Submoduleとして管理する方法
api-schemaを独立したリポジトリとして作成:

```
cd common/api-schema
git init
git remote add origin git@github.com:your-org/api-schema.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

フロントエンド/バックエンドプロジェクトでsubmoduleとして追加:

```
# フロントエンドプロジェクト
cd frontend
git submodule add git@github.com:your-org/api-schema.git common/api-schema

# バックエンドプロジェクト
cd backend
git submodule add git@github.com:your-org/api-schema.git common/api-schema
```

3. モノレポツールを使用する方法
NxやTurborepoなどのモノレポツールを使用して管理:

```
{
  "name": "your-project",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ],
  "dependencies": {
    "turbo": "latest"
  }
}
```

```
{
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    }
  }
}
```

推奨アプローチ
上記の方法の中で、以下を推奨します：

1. 開発フェーズ: Git Submoduleを使用

- メリット:
    - 変更の追跡が容易
    - バージョン管理が簡単
    - 即座に変更を反映可能

2. 本番デプロイ: npmパッケージとして公開

- メリット:
    - デプロイが安定
    - バージョニングが明確
    - 依存関係の管理が容易
    - CI/CD設定例
    
これにより、開発時の柔軟性と本番環境の安定性の両方を確保できます。
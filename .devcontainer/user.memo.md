## tailscale

`sudo tailscale up -ssh -hostname mac-hono`
`sudo tailscale funnel -bg -https=10000 8787`

## wrangler login

`npx wrangler login`

<!-- 以下の方法でmacでしか成功しなかった -->
<!-- https://zenn.dev/frog/articles/f77b80a0d78497 -->

`npx wrangler whoami`

## wrangler dev 用の環境変数ファイルの作成 (.env へのシンボリックリンク)

`ln -s .env .dev.vars`

## D1

<!-- webGUIから作成したDBではマイグレーションが効かなかったのでCLIから作成した -->

0. npx wrangler d1 create {hono-prisma-db}
<!-- マイグレーション -->
1. npx wrangler d1 migrations create DB {create_imageset_table}
2.
3. （初回）npx prisma migrate diff --from-empty --to-schema-datamodel ./prisma/d1/schema.sqlite.prisma --script >> ./prisma/d1/migrations/{0001_create_imageset_table.sql}
4. （追加）npx prisma migrate diff --from-schema-datamodel ./prisma/d1/schema.sqlite.prisma --to-schema-datamodel ./prisma/d1/schema.sqlite.prisma --script >> ./prisma/d1/migrations/{0002_add_new_column_to_existing_table.sql}

5. npx wrangler d1 migrations apply DB --local
6. npx wrangler d1 migrations apply DB --remote
   <!-- テーブル確認. --> npx wrangler d1 execute DB --local --command "SELECT name FROM sqlite_master WHERE type='table';"
   <!-- カラム確認. --> npx wrangler d1 execute DB --local --command "PRAGMA table_info('dm_image_sets');"

<!-- prismaクライアント再作成 -->

5. npx prisma generate --schema=./prisma/d1/schema.sqlite.prisma

<!-- シード作成 -->

npx wrangler d1 execute DB --local --file='./prisma/seeds/initial.d1.sql'
npx wrangler d1 execute DB --local --command "SELECT \* FROM am_users;"

## cockroachdb

※1 Cloudflare Workers で Prisma を使用する場合、Prisma の Edge 機能を利用する事になるが、
Engine 部分が Cloudflare Workers 上で動作しない為リモート上に別途用意し、そこ経由で接続する必要があります。
Prisma Accelerate などの外部サービスを使って接続可能です。https://zenn.dev/slowhand/articles/30c6bc9fd418ab

※2 Cloudflare Workers で Prisma を使用するには、
Prisma Accelerate を使用する方法とドライバー アダプターを使用する方法の 2 つがあります。https://hono.dev/examples/prisma

※3 cockroach ではドライバー アダプターが使用できないため Prisma Accelerate を使用する必要があります。https://console.prisma.io/

Prisma Accelerate 管理画面（google 認証）
https://console.prisma.io

<!-- マイグレーション -->

1. npx prisma migrate dev --name {init}
<!-- シード -->
1. npx prisma db seed
<!-- 確認 -->
1. npx ts-node --compiler-options {\"module\":\"commonjs\"} prisma/seeds/seed.check.ts
<!-- prismaクライアント再作成 -->
npx prisma generate --no-engine

## r2
<!-- バケット一覧取得 -->
npx wrangler r2 bucket list
<!-- サンプルファイルのアップロード -->
echo "This is a sample text file." > sample.txt && npx wrangler r2 object put hono-backend/sample.txt --file sample.txt
<!-- サンプルファイルのダウンロード -->
npx wrangler r2 object get hono-backend/sample.txt
<!-- サンプルファイルの削除 -->
npx wrangler r2 object delete hono-backend/sample.txt

sudo apt-get update && sudo apt-get install ca-certificates


## vitest

## zod

## hono rpc

## trpc

## キャッシュパージ
<!-- トークン有効性確認 -->
curl -X GET "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/tokens/verify" \
     -H "Authorization: Bearer ${CF_API_TOKEN}" \
     -H "Content-Type:application/json"

<!-- ゾーンIDがわからず不可 -->
curl -X POST "https://api.cloudflare.com/client/v4/zones/[ゾーンID]/purge_cache" -H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json" --data '{"purge_everything":true}' 

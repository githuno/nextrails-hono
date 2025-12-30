https://www.notion.so/React-Hook-Form-Zod-DEV-Community-2a5565e97d7c810db8c7cc94e45f25dd

https://aistudio.google.com/app/prompts?state=%7B%22ids%22:%5B%221jfkh4rNtiqBk_PaJDQ2tcsCaeG0RRw4q%22%5D,%22action%22:%22open%22,%22userId%22:%22110540619162880680792%22,%22resourceKeys%22:%7B%7D%7D&usp=sharing

1つのファイル内で、**バックエンドとフロントエンドで共有するロジック**と、**フロントエンド専用のロジック**を、それぞれ別のオブジェクトにまとめてエクスポートする方法は、この問題に対する非常に洗練されたベストプラクティスです。

このアプローチにより、以下の全てを実現できます。

*   関連するロジックを1つのファイルで管理できる。
*   `UserShared.profileSchema` のように、名前空間を使ってロジックを整理できる。
*   バックエンドはフロントエンド専用のライブラリに依存することなく、安全に必要なものだけをインポートできる。

### 実装方法

まさにあなたのアイデアをコードにしたものがこちらです。

**`src/lib/user.js`** （ファイル名をより汎用的にしました）

```javascript
import { z } from "zod";
import { zodResolver } from "@hookform/resolvers/zod";

// --- 1. 共有ロジックの定義 ---
// これらはバックエンドでもフロントエンドでも安全に使える

const profileSchema = z.object({
  username: z.string().min(1, { message: "Username is required" }),
  age: z.number().min(18, { message: "Must be at least 18" }),
  subscribe: z.boolean().default(false),
});

const formToApi = (formData) => ({
  user_name: formData.username,
  user_age: formData.age,
  newsletter_opt_in: formData.subscribe ? 1 : 0,
});

const apiToForm = (apiData = {}) => ({
  username: apiData.user_name || "",
  age: apiData.user_age || 18,
  subscribe: Boolean(apiData.newsletter_opt_in),
});

/**
 * 共有ロジックをまとめたオブジェクト
 * バックエンドとフロントエンドの両方からインポートして使用する
 */
export const UserShared = {
  profileSchema,
  formToApi,
  apiToForm,
};


// --- 2. フロントエンド専用ロジックの定義 ---
// これらは React や react-hook-form に依存する

const getDefaultValues = (data) => {
  return data ? UserShared.apiToForm(data) : UserShared.apiToForm();
};

const getFormOptions = (defaultValues) => {
  return {
    // 共有ロジックからスキーマを参照
    resolver: zodResolver(UserShared.profileSchema),
    defaultValues: defaultValues,
  };
};

/**
 * フロントエンドのフォームに特化したロジックをまとめたオブジェクト
 * フロントエンドのカスタムフックなどからインポートして使用する
 */
export const UserForm = {
  getDefaultValues,
  getFormOptions,
};
```

### このパターンの使い方

#### バックエンドでの使用例

バックエンドは `UserShared` のみインポートします。これにより `@hookform/resolvers/zod` は一切ロードされません。

```javascript
// /pages/api/update-user.js
import { UserShared } from '../../lib/user';

export default function handler(req, res) {
  try {
    // 安全に共有スキーマを利用してバリデーション
    const validatedData = UserShared.profileSchema.parse(req.body);
    
    // データベース用の形式に変換
    const apiData = UserShared.formToApi(validatedData);
    
    // ...データベース処理...

    res.status(200).json({ message: 'Success' });
  } catch (error) {
    res.status(400).json({ message: 'Invalid data', errors: error.errors });
  }
}
```

#### フロントエンドでの使用例

フロントエンドは `UserShared` と `UserForm` の両方をインポートして、フックを組み立てます。

```javascript
// /hooks/useProfileForm.js
import { useMemo } from 'react';
import { useForm } from 'react-hook-form';
import { UserShared, UserForm } from '../lib/user';

export const useProfileForm = ({ data } = {}) => {
  const defaults = useMemo(() => UserForm.getDefaultValues(data), [data]);
  
  const formOptions = useMemo(() => UserForm.getFormOptions(defaults), [defaults]);

  const form = useForm(formOptions);

  return {
    schema: UserShared.profileSchema,
    form,
    // formToApi も渡してあげるとコンポーネント側で便利
    formToApi: UserShared.formToApi,
  };
};
```

### このアプローチの絶大なメリット

*   **完全な依存関係の分離**: バックエンドはフロントエンドの依存関係から完全に隔離されます。
*   **高い可読性と自己文書化**: `UserShared` や `UserForm` という名前自体が、そのオブジェクトが持つロジックの役割を明確に物語っています。
*   **優れた保守性**: ユーザー関連のスキーマやロジックはすべて `src/lib/user.js` に集約されているため、仕様変更時の修正箇所が明確です。
*   **単一責任の原則**: `UserShared` はデータ構造と変換の責任を持ち、`UserForm` はUIフォームのセットアップの責任を持つ、というように責任が分離されています。

この方法は、コードの整理、再利用性、そして安全性のバランスを取るための、非常に洗練された現実的な解決策と言えます。
# shop_hub

Flutter Webでつくる、日本語のネットショップ管理サービスのモック版です。
ログイン・決済・カート・画像アップロード・本番Firestoreへの書き込みは実装していません。
データはアプリの起動中だけ保持され、ブラウザの再読み込みでサンプルに戻ります。

## 開発

検証環境：Flutter 3.41.6 / Dart 3.11.4。

```sh
# このクラウド環境でSDKとキャッシュの場所を設定
source /workspace/toolchains/shop-hub-env.sh
cd /workspace/shop_hub
flutter pub get --enforce-lockfile
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8081 --no-web-resources-cdn
```

既存のチェックアウトを利用してください。クラウドタスクごとに環境は分離されるため、通常はworktree作成は不要です。
`www.gstatic.com`へのHTTPS接続がFirebase Web SDKの初期化に必要です。
接続できない場合は再試行するか、「デモを開く」でモック画面を利用できます。
SDKのインストール・更新には `github.com`、`storage.googleapis.com`、`pub.dev`への接続が必要です。

## 画面

- `/admin`：ダッシュボード。キャンセルを除いた当月のサンプル売上・注文数、商品数、公開状態。
- `/admin/products`：検索・追加・編集・削除・公開切り替え。
- `/admin/products/:id`：管理者向け商品詳細。
- `/admin/orders`：サンプル注文一覧・詳細。新しい注文を発生させる機能はありません。
- `/admin/settings`：ショップ情報・URL用ID・公開状態の編集と保存済みページのプレビュー。
- `/shop/atelier`：公開ショップ。URL用IDを変更した場合は新しいIDのURLを利用します。
- `/shop/:slug/products/:id`：公開商品の詳細。非公開商品や非公開ショップは表示しません。

ルーティングはgo_router（標準のハッシュURL）、状態管理はRiverpod、UIはMaterial 3です。
PCはサイドメニュー、スマートフォンはDrawerを使用します。
Firebaseは既存の `lib/firebase_options.dart` で初期化します。現在のデータ操作はすべてモックです。
公開・非公開は今回の画面表示制御であり、本番サービスのアクセス制御にはFirebase Security Rules等が別途必要です。

## データ構成

`lib/models`にモデル、`lib/data/shop_repository.dart`にデータ操作のインターフェースとモック実装、
`lib/data/providers.dart`にショップID別のRiverpodプロバイダー、`lib/screens`に管理・公開画面を配置しています。

将来の保存先は `users/{uid}`、`shops/{shopId}`、
`shops/{shopId}/products/{productId}`、`shops/{shopId}/orders/{orderId}` を想定しています。
現在はデモショップ1店舗を表示します。複数店舗への拡張時はショップ選択とURL用IDの索引を追加し、
ShopRepositoryの実装をFirestoreに差し替えます。URL用IDは保存側でも重複を検査しています。
本番での重複防止はサーバー側のトランザクション等で一意性を保証してください。

## 検証

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub --no-web-resources-cdn
```

テストは商品CRUD、ショップ間の分離、URL用IDの検証、ダッシュボード、公開制御、
スマートフォンの画面遷移、商品フォームの入力検証と操作を確認します。
日本語フォントはNoto Sans JPを同梱し、ライセンスは `assets/fonts/OFL.txt` に収録しています。

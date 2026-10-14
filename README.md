# shop_hub

Flutter Webでつくる、日本語のネットショップ管理サービスのモック版です。
ログイン・決済・カート・クラウドへの画像保存・本番Firestoreへの書き込みは実装していません。
データはアプリの起動中だけ保持され、ブラウザの再読み込みで初期状態に戻ります。商品・注文は0件、ショップ名・説明は未設定で、ショップは非公開です。

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

- `/admin`：ダッシュボード。キャンセルを除いた当月の売上・注文数、商品数、公開状態。
- `/admin/products`：検索・追加・編集・削除・公開切り替え。
- `/admin/products/:id`：管理者向け商品詳細。
- `/admin/orders`：注文一覧・詳細（初期状態は0件）。新しい注文を発生させる機能はありません。
- `/admin/settings`：ショップ情報・URL用ID・公開状態の編集と保存済みページのプレビュー。
- `/shop/shop`：公開ショップ。URL用IDを変更した場合は新しいIDのURLを利用します。
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
現在はショップ1店舗を管理します。複数店舗への拡張時はショップ選択とURL用IDの索引を追加し、
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

## 商品画像

商品フォームでJPEG・PNG・WebPを選択、または画像欄にドラッグ＆ドロップできます。
1商品最大5枚、1枚5MB（5×1024×1024バイト）までです。ファイルの内容・拡張子・デコード結果を検証します。
選択直後にプレビューを表示し、削除、ドラッグでの並び替え（スマートフォンは長押し）、矢印ボタンでの並び替えに対応しています。
1枚目をメイン画像として管理・公開商品一覧に表示し、商品詳細ではサムネイルで表示画像を切り替えられます。
画像なしの場合はプレースホルダーを表示します。編集をキャンセルすると元の商品画像は変わりません。

現在は認証とショップ所有者を検証する安全なアップロード経路がないため、Firebase Storageへの保存は保留しています。
画像はRiverpodとモックリポジトリを使い、このタブのアプリ起動中だけ保持します。再読み込みで消え、他のタブやブラウザには共有されません。
画面にもクラウド保存の保留と一時保持を表示します。ログイン・匿名ログイン・公開書き込みルール・Security Rulesの変更／デプロイは追加していません。

`imageStorageProvider` の標準実装はネットワーク通信を行わない `DeferredImageStorage` です。
将来用の `FirebaseProductImageStorage` は、サインイン済みの非匿名ユーザーと、注入されたサーバー側のショップ所有者検証を必須とし、
`shops/{shopId}/products/{productId}/images/{imageId}.{extension}` に保存する構成です。
このアダプターは現在のアプリには接続していません。クライアントの権限チェックだけでは安全性を保証できないため、
有効化する前に所有者の認証経路、独立したStorage側の権限検証、公開画像の読み取り方針を整備してください。

Storageアダプターには転送進捗通知、失敗時の新規画像の削除、画像パスの範囲検証を備えています。
`ProductImageService` は商品保存後に削除対象画像を整理し、商品削除では先に画像削除を確認します。
後処理に失敗した画像参照は一時的な再試行キューに残します。実際のクラウド連携では、保留参照をサーバー側に永続化する回復処理も必要です。
実Firebase Storageへのアップロード・削除は今回の検証対象に含めません。

プラグイン追加・更新後にWebの生成済み登録コードが古い場合は、次の手順でキャッシュを再生成してください。

```sh
flutter clean
flutter pub get --enforce-lockfile
flutter build web --no-web-resources-cdn --no-wasm-dry-run
```

既存の生成キャッシュを引き継いだ環境で画像選択のWebプラグインが登録されない問題を確認し、この手順で登録コードを再生成しました。

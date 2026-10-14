import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shop_hub/main.dart';
import 'package:shop_hub/data/providers.dart';
import 'package:shop_hub/data/shop_repository.dart';
import 'package:shop_hub/models/shop_models.dart';
import 'shop_fixtures.dart';

void main() {
  test('mock CRUD persists and isolates shops', () async {
    final repo = MockShopRepository();
    const product = Product(
      id: 'new',
      shopId: 'demo',
      name: '新商品',
      description: '説明',
      price: 1500,
      stock: 2,
    );
    await repo.saveProduct(product);
    expect((await repo.loadProducts('demo')).any((p) => p.id == 'new'), isTrue);
    expect(await repo.loadProducts('other'), isEmpty);
    await repo.saveProduct(
      const Product(
        id: 'new',
        shopId: 'demo',
        name: '編集済み',
        description: '',
        price: 2000,
        stock: 0,
        published: false,
      ),
    );
    expect(
      (await repo.loadProducts('demo')).singleWhere((p) => p.id == 'new').name,
      '編集済み',
    );
    await repo.deleteProduct('other', 'new');
    expect((await repo.loadProducts('demo')).any((p) => p.id == 'new'), isTrue);
    await repo.deleteProduct('demo', 'new');
    expect(
      (await repo.loadProducts('demo')).any((p) => p.id == 'new'),
      isFalse,
    );
  });
  test('URL IDs reject duplicates and invalid forms', () async {
    final repo = MockShopRepository();
    expect(await repo.isSlugAvailable('shop', 'other'), isFalse);
    expect(await repo.isSlugAvailable('shop', 'demo'), isTrue);
    await expectLater(
      repo.saveShop(
        const Shop(id: 'other', name: '別店舗', description: '', slug: 'shop'),
      ),
      throwsStateError,
    );
    await expectLater(
      repo.saveShop(
        const Shop(id: 'other', name: '別店舗', description: '', slug: '../bad'),
      ),
      throwsArgumentError,
    );
  });
  test(
    'repository starts without sample products, orders or shop information',
    () async {
      final repo = MockShopRepository();
      expect(await repo.loadProducts('demo'), isEmpty);
      expect(await repo.loadOrders('demo'), isEmpty);
      final shop = await repo.loadShop('demo');
      expect(shop.name, isEmpty);
      expect(shop.description, isEmpty);
      expect(shop.published, isFalse);
    },
  );
  testWidgets('dashboard starts with zero metrics and no orders', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ShopHubApp()));
    await tester.pumpAndSettle();
    expect(find.text('今月の売上'), findsOneWidget);
    expect(find.text('¥0'), findsOneWidget);
    expect(find.text('0件'), findsOneWidget);
    expect(find.text('0点'), findsNWidgets(2));
    expect(find.text('注文はまだありません'), findsOneWidget);
    expect(find.text('ショップ名を設定してください'), findsOneWidget);
  });
  testWidgets('store hides unpublished products and private shops', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await seedShop(container.read(repositoryProvider));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/shop/test-shop');
    await tester.pumpAndSettle();
    expect(find.text('公開商品'), findsOneWidget);
    expect(find.text('非公開商品'), findsNothing);
    final shop = await container.read(repositoryProvider).loadShop('demo');
    await container
        .read(repositoryProvider)
        .saveShop(
          Shop(
            id: shop.id,
            name: shop.name,
            description: shop.description,
            slug: shop.slug,
            published: false,
          ),
        );
    container.invalidate(shopProvider('demo'));
    await tester.pumpAndSettle();
    expect(find.text('ただいま準備中です'), findsOneWidget);
    expect(find.text('公開商品'), findsNothing);
  });
  testWidgets('mobile drawer routes to product registration', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: ShopHubApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商品管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商品を登録'));
    await tester.pumpAndSettle();
    expect(find.text('商品名'), findsWidgets);
  });
  testWidgets('product form validates, saves, edits, searches and deletes', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = container.read(routerProvider);
    router.go('/admin/products');
    await tester.pumpAndSettle();
    expect(find.text('商品がまだ登録されていません'), findsOneWidget);
    await tester.tap(find.text('商品を登録する'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'テスト商品');
    await tester.enterText(fields.at(1), '新しい商品の説明');
    await tester.enterText(fields.at(2), '-1');
    await tester.enterText(fields.at(3), '3');
    final save = find.text('商品を登録');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('0〜999999999の整数を入力してください'), findsOneWidget);
    await tester.enterText(fields.at(2), '1800');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    final repo = container.read(repositoryProvider);
    final product = (await repo.loadProducts(
      'demo',
    )).singleWhere((p) => p.name == 'テスト商品');
    expect(product.published, isFalse);
    expect(product.price, 1800);
    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('1点'), findsOneWidget);
    expect(find.text('0点'), findsOneWidget);
    router.go('/admin/products/${product.id}/edit');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '編集した商品');
    await tester.ensureVisible(find.text('変更を保存'));
    await tester.tap(find.text('変更を保存'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '編集した商品');
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(TextButton),
        matching: find.text('編集した商品'),
      ),
      findsOneWidget,
    );
    expect(find.text('公開商品'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '一致しない検索語');
    await tester.pumpAndSettle();
    expect(find.text('該当する商品がありません'), findsOneWidget);
    expect(find.text('商品がまだ登録されていません'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '編集した商品');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('1点'), findsNWidgets(2));
    expect(find.text('¥0'), findsOneWidget);
    expect(find.text('0件'), findsOneWidget);
    router.go('/admin/products');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('削除'));
    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(
      (await repo.loadProducts('demo')).any((p) => p.id == product.id),
      isFalse,
    );
    expect(find.text('商品がまだ登録されていません'), findsOneWidget);
    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('0点'), findsNWidgets(2));
  });
  testWidgets('private product URL does not reveal details', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await seedShop(container.read(repositoryProvider));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    container.read(routerProvider).go('/shop/test-shop/products/p4');
    await tester.pumpAndSettle();
    expect(find.text('商品が見つかりません'), findsOneWidget);
    expect(find.text('非公開商品'), findsNothing);
  });
  testWidgets('shop settings persist and update the public URL', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    final router = container.read(routerProvider);
    router.go('/admin/settings');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '新しいショップ');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-shop');
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('設定を保存'));
    await tester.tap(find.text('設定を保存'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(repositoryProvider).loadShop('demo')).slug,
      'new-shop',
    );
    router.go('/shop/shop');
    await tester.pumpAndSettle();
    expect(find.text('ショップが見つかりません'), findsOneWidget);
    router.go('/shop/new-shop');
    await tester.pumpAndSettle();
    expect(find.text('新しいショップ'), findsOneWidget);
  });
  testWidgets('all representative pages fit a narrow mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        ordersProvider('demo').overrideWith((ref) async => testOrders),
      ],
    );
    addTearDown(container.dispose);
    await seedShop(container.read(repositoryProvider));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    for (final path in [
      '/admin/products',
      '/admin/products/p1',
      '/admin/products/p1/edit',
      '/admin/orders',
      '/admin/orders/TEST-ORDER',
      '/admin/settings',
      '/shop/test-shop',
      '/shop/test-shop/products/p1',
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}

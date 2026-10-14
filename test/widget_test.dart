import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shop_hub/main.dart';
import 'package:shop_hub/data/providers.dart';
import 'package:shop_hub/data/shop_repository.dart';
import 'package:shop_hub/models/shop_models.dart';

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
    expect(await repo.isSlugAvailable('atelier', 'other'), isFalse);
    expect(await repo.isSlugAvailable('atelier', 'demo'), isTrue);
    await expectLater(
      repo.saveShop(
        const Shop(id: 'other', name: '別店舗', description: '', slug: 'atelier'),
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
  testWidgets('dashboard loads sample metrics', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ShopHubApp()));
    await tester.pumpAndSettle();
    expect(find.text('登録商品数'), findsOneWidget);
    expect(find.text('4点'), findsOneWidget);
    expect(find.text('3点'), findsOneWidget);
  });
  testWidgets('store hides unpublished products and private shops', (
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
    container.read(routerProvider).go('/shop/atelier');
    await tester.pumpAndSettle();
    expect(find.text('キャンバストートバッグ'), findsOneWidget);
    expect(find.text('季節のポストカードセット'), findsNothing);
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
    expect(find.text('キャンバストートバッグ'), findsNothing);
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
    router.go('/admin/products/new');
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'テスト商品');
    await tester.enterText(fields.at(1), '新しい商品の説明');
    await tester.enterText(fields.at(2), '-1');
    await tester.enterText(fields.at(3), '3');
    final save = find.text('商品を保存');
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
    router.go('/admin/products/${product.id}/edit');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '編集した商品');
    await tester.ensureVisible(find.text('商品を保存'));
    await tester.tap(find.text('商品を保存'));
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
    expect(find.text('キャンバストートバッグ'), findsNothing);
    await tester.ensureVisible(find.byTooltip('削除'));
    await tester.tap(find.byTooltip('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(
      (await repo.loadProducts('demo')).any((p) => p.id == product.id),
      isFalse,
    );
  });
  testWidgets('private product URL does not reveal details', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    container.read(routerProvider).go('/shop/atelier/products/p4');
    await tester.pumpAndSettle();
    expect(find.text('商品が見つかりません'), findsOneWidget);
    expect(find.text('季節のポストカードセット'), findsNothing);
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
    await tester.ensureVisible(find.text('設定を保存'));
    await tester.tap(find.text('設定を保存'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(repositoryProvider).loadShop('demo')).slug,
      'new-shop',
    );
    router.go('/shop/atelier');
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
    final container = ProviderContainer();
    addTearDown(container.dispose);
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
      '/admin/orders/SH-1003',
      '/admin/settings',
      '/shop/atelier',
      '/shop/atelier/products/p1',
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}

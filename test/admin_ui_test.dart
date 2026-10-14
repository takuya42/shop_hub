import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_hub/data/providers.dart';
import 'package:shop_hub/main.dart';
import 'package:shop_hub/screens/product_form_widgets.dart';

void main() {
  for (final width in [1280.0, 390.0]) {
    testWidgets('product form layout adapts at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
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
      container.read(routerProvider).go('/admin/products/new');
      await tester.pumpAndSettle();
      final row = find.byWidgetPredicate(
        (w) => w is ProductFormRow && w.label == '商品名',
      );
      final label = find.descendant(of: row, matching: find.text('商品名'));
      final input = find.descendant(
        of: row,
        matching: find.byType(TextFormField),
      );
      final labelRect = tester.getRect(label);
      final inputRect = tester.getRect(input);
      if (width >= 900) {
        expect(labelRect.right, lessThan(inputRect.left));
        expect(labelRect.top, lessThan(inputRect.top + 30));
      } else {
        expect(labelRect.bottom, lessThan(inputRect.top));
      }
      expect(find.text('必須'), findsNWidgets(2));
      expect(find.text('画像を選択'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unfinished navigation items remain on the current page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
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
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('商品管理'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    for (final name in ['顧客管理', '売上管理', 'データ分析', 'ショップデザイン']) {
      final tile = find.widgetWithText(ListTile, name);
      final widget = tester.widget<ListTile>(tile);
      expect(widget.enabled, isFalse);
      expect(widget.onTap, isNull);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(
        container.read(routerProvider).routeInformationProvider.value.uri.path,
        '/admin',
      );
    }
    expect(find.text('準備中'), findsNWidgets(4));
    semantics.dispose();
  });

  testWidgets('preview validates input and never saves the product', (
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
    container.read(routerProvider).go('/admin/products/new');
    await tester.pumpAndSettle();
    final initial = await container
        .read(repositoryProvider)
        .loadProducts('demo');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('プレビュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プレビュー'));
    await tester.pumpAndSettle();
    expect(find.text('商品名を入力してください'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'プレビュー専用の商品');
    await tester.enterText(find.byType(TextFormField).at(1), '保存前の商品説明');
    await tester.enterText(find.byType(TextFormField).at(2), '2500');
    await tester.enterText(find.byType(TextFormField).at(3), '7');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('プレビュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プレビュー'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('プレビュー専用の商品')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('¥2,500')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('在庫 7点')),
      findsOneWidget,
    );
    expect(
      (await container.read(repositoryProvider).loadProducts('demo')).length,
      initial.length,
    );
    await tester.tap(find.text('編集に戻る'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'プレビュー専用の商品',
    );
  });
}

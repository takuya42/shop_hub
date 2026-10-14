import 'dart:io';
import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shop_hub/data/images/image_draft.dart';
import 'package:shop_hub/data/images/image_storage.dart';
import 'package:shop_hub/data/images/product_image_service.dart';
import 'package:shop_hub/data/providers.dart';
import 'package:shop_hub/data/shop_repository.dart';
import 'package:shop_hub/main.dart';
import 'package:shop_hub/models/product_image.dart';
import 'package:shop_hub/models/shop_models.dart';
import 'package:shop_hub/screens/product_image_editor.dart';
import 'package:shop_hub/screens/product_images.dart';

Uint8List fixture(String name) => File('test/fixtures/$name').readAsBytesSync();
XFile picked(String name, [Uint8List? bytes]) =>
    XFile.fromData(bytes ?? fixture(name), name: name, path: name);
ProductImage image(String id) => ProductImage.local(
  id: id,
  name: '$id.png',
  contentType: 'image/png',
  bytes: fixture('image.png'),
);
Product product(List<ProductImage> images) => Product(
  id: 'p1',
  shopId: 'demo',
  name: '画像付き商品',
  description: '',
  price: 1000,
  stock: 1,
  images: images,
);

class OversizedFile extends XFile {
  OversizedFile() : super('large.png');
  bool read = false;
  @override
  Future<int> length() async => maxImageBytes + 1;
  @override
  Future<Uint8List> readAsBytes() async {
    read = true;
    throw StateError('Oversized files must not be read');
  }
}

class NoUserAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected Auth call');
}

class TestUser implements User {
  TestUser({this.isAnonymous = false});
  @override
  final bool isAnonymous;
  @override
  String get uid => 'test-user';
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected User call');
}

class SignedInAuth extends NoUserAuth {
  SignedInAuth(this.user);
  final User user;
  @override
  User? get currentUser => user;
}

class NeverStorage implements FirebaseStorage {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Storage must not be called');
  }
}

class RecordingStorage implements ProductImageStorage {
  final deleted = <List<ProductImage>>[];
  bool failDelete = false;
  @override
  bool get remoteEnabled => true;
  @override
  Future<List<ProductImage>> save(
    String shopId,
    String productId,
    List<ProductImage> images, {
    void Function(double)? onProgress,
  }) async => images
      .map(
        (i) => i.bytes == null
            ? i
            : ProductImage.remote(
                id: i.id,
                name: i.name,
                contentType: i.contentType,
                url: 'https://example.invalid/${i.id}',
                storagePath: productImagePath(shopId, productId, i),
              ),
      )
      .toList();
  @override
  Future<void> delete(
    String shopId,
    String productId,
    List<ProductImage> images,
  ) async {
    if (failDelete) throw const ImageStorageException('権限エラー');
    deleted.add(images);
  }
}

class FailingRepository extends MockShopRepository {
  @override
  Future<void> saveProduct(Product product) async =>
      throw StateError('Metadata save failed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final format in ['image.png', 'image.jpg', 'image.webp']) {
    test('selects and decodes $format', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = ImageDraftKey();
      final listener = container.listen(imageDraftProvider(key), (_, _) {});
      addTearDown(listener.close);
      await container.read(imageDraftProvider(key).notifier).addFiles([
        picked(format),
      ]);
      final draft = container.read(imageDraftProvider(key));
      expect(draft.error, isNull);
      expect(draft.images.single.name, format);
      expect(draft.images.single.bytes, isNotEmpty);
      expect(draft.reading, isFalse);
    });
  }
  test(
    'limits count, rejects spoofed and corrupt images atomically, supports reorder/removal',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = ImageDraftKey();
      final listener = container.listen(imageDraftProvider(key), (_, _) {});
      addTearDown(listener.close);
      final controller = container.read(imageDraftProvider(key).notifier);
      await controller.addFiles([picked('image.png')]);
      await controller.addFiles([
        picked('image.png'),
        picked('spoof.jpg', fixture('image.png')),
      ]);
      expect(container.read(imageDraftProvider(key)).images.length, 1);
      expect(container.read(imageDraftProvider(key)).error, contains('一致'));
      await controller.addFiles([
        picked(
          'corrupt.png',
          Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
      ]);
      expect(container.read(imageDraftProvider(key)).error, isNotNull);
      await controller.addFiles([
        picked('file.svg', Uint8List.fromList([1, 2, 3])),
      ]);
      expect(container.read(imageDraftProvider(key)).error, contains('JPEG'));
      await controller.addFiles(List.generate(4, (_) => picked('image.png')));
      final before = container.read(imageDraftProvider(key)).images;
      expect(before.length, 5);
      expect(before.map((i) => i.id).toSet().length, 5);
      await controller.addFiles([picked('image.png')]);
      expect(container.read(imageDraftProvider(key)).images.length, 5);
      expect(container.read(imageDraftProvider(key)).error, contains('最大5枚'));
      controller.move(4, 0);
      expect(
        container.read(imageDraftProvider(key)).images.first.id,
        before.last.id,
      );
      controller.remove(before.last.id);
      expect(container.read(imageDraftProvider(key)).images.length, 4);
    },
  );
  test(
    'rejects files over 5MB before reading and accepts the exact limit',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final key = ImageDraftKey();
      final listener = container.listen(imageDraftProvider(key), (_, _) {});
      addTearDown(listener.close);
      final controller = container.read(imageDraftProvider(key).notifier);
      final large = OversizedFile();
      await controller.addFiles([large]);
      expect(large.read, isFalse);
      expect(container.read(imageDraftProvider(key)).error, contains('5MB'));
      final bytes = Uint8List(maxImageBytes)
        ..setRange(0, fixture('image.png').length, fixture('image.png'));
      await controller.addFiles([picked('limit.png', bytes)]);
      expect(container.read(imageDraftProvider(key)).error, isNull);
      expect(
        container.read(imageDraftProvider(key)).images.single.bytes!.length,
        maxImageBytes,
      );
    },
  );
  test(
    'local bytes and saved image order cannot be mutated externally',
    () async {
      final bytes = fixture('image.png');
      final value = ProductImage.local(
        id: 'i1',
        name: 'image.png',
        contentType: 'image/png',
        bytes: bytes,
      );
      bytes[0] = 0;
      expect(value.bytes![0], 137);
      expect(() => value.bytes![0] = 0, throwsUnsupportedError);
      final images = [value];
      final repo = MockShopRepository();
      await repo.saveProduct(product(images));
      images.clear();
      expect((await repo.loadProducts('demo')).single.images.length, 1);
      final savedImages = (await repo.loadProducts('demo')).single.images;
      expect(() => savedImages.clear(), throwsUnsupportedError);
    },
  );
  test(
    'default storage persists locally without initializing Firebase',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(imageStorageProvider).remoteEnabled, isFalse);
      await container
          .read(productImageServiceProvider)
          .save(product([image('a')]));
      final saved =
          (await container.read(repositoryProvider).loadProducts('demo'))
              .single;
      expect(saved.images.single.bytes, isNotNull);
      expect(saved.images.single.storagePath, isNull);
      await container.read(productImageServiceProvider).delete(saved);
      expect(
        await container.read(repositoryProvider).loadProducts('demo'),
        isEmpty,
      );
    },
  );
  test(
    'Storage upload/delete is denied before any SDK call without authentication',
    () async {
      final storage = NeverStorage();
      var ownershipChecked = false;
      final adapter = FirebaseProductImageStorage(
        storage: storage,
        auth: NoUserAuth(),
        ownsShop: (_, _) async {
          ownershipChecked = true;
          return true;
        },
      );
      await expectLater(
        adapter.save('demo', 'p1', [image('a')]),
        throwsA(isA<ImageStorageException>()),
      );
      final remote = ProductImage.remote(
        id: 'a',
        name: 'a.png',
        contentType: 'image/png',
        url: 'https://example.invalid/a',
        storagePath: productImagePath('demo', 'p1', image('a')),
      );
      await expectLater(
        adapter.delete('demo', 'p1', [remote]),
        throwsA(isA<ImageStorageException>()),
      );
      expect(storage.calls, 0);
      expect(ownershipChecked, isFalse);
      expect(
        () => productImagePath('../other', 'p1', image('a')),
        throwsA(isA<ImageStorageException>()),
      );
      expect(
        () => adapter.validate('other', 'p1', remote),
        throwsA(isA<ImageStorageException>()),
      );
    },
  );
  test(
    'anonymous users and non-owners are denied before Storage access',
    () async {
      for (final anonymous in [true, false]) {
        final storage = NeverStorage();
        var verified = false;
        final adapter = FirebaseProductImageStorage(
          storage: storage,
          auth: SignedInAuth(TestUser(isAnonymous: anonymous)),
          ownsShop: (_, _) async {
            verified = true;
            return false;
          },
        );
        await expectLater(
          adapter.save('demo', 'p1', [image('a')]),
          throwsA(isA<ImageStorageException>()),
        );
        expect(storage.calls, 0);
        expect(verified, !anonymous);
      }
    },
  );
  test(
    'metadata failure rolls back new uploads; cleanup failure preserves references',
    () async {
      final storage = RecordingStorage();
      final service = ProductImageService(FailingRepository(), storage);
      await expectLater(service.save(product([image('a')])), throwsStateError);
      expect(storage.deleted.single.single.id, 'a');
      storage.failDelete = true;
      await expectLater(service.save(product([image('b')])), throwsStateError);
      expect(service.pendingCleanup.single.images.single.id, 'b');
      storage.failDelete = false;
      await service.retryPendingCleanup();
      expect(service.pendingCleanup, isEmpty);
    },
  );
  test(
    'removal cleanup warnings do not lose saved metadata; deletion failure preserves product',
    () async {
      final repo = MockShopRepository();
      final storage = RecordingStorage();
      final service = ProductImageService(repo, storage);
      await service.save(product([image('a'), image('b')]));
      final saved = (await repo.loadProducts('demo')).single;
      storage.failDelete = true;
      expect(await service.save(product([saved.images.last])), isNotNull);
      expect((await repo.loadProducts('demo')).single.images.single.id, 'b');
      expect(service.pendingCleanup.single.images.single.id, 'a');
      await expectLater(
        service.delete((await repo.loadProducts('demo')).single),
        throwsA(isA<ImageStorageException>()),
      );
      expect((await repo.loadProducts('demo')).length, 1);
      storage.failDelete = false;
      await service.retryPendingCleanup();
      await service.delete((await repo.loadProducts('demo')).single);
      expect(await repo.loadProducts('demo'), isEmpty);
    },
  );

  testWidgets('picker, reorder, drop, removal, save and edit preserve images', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        imagePickerProvider.overrideWithValue(
          () async => [picked('image.png'), picked('image.jpg')],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    container.read(routerProvider).go('/admin/products/new');
    await tester.pumpAndSettle();
    final editor = tester.widget<ProductImageEditor>(
      find.byType(ProductImageEditor),
    );
    await tester.ensureVisible(find.text('画像を選択'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('画像を選択'));
      final stopwatch = Stopwatch()..start();
      await Future<void>.delayed(Duration.zero);
      while (container.read(imageDraftProvider(editor.draftKey)).reading) {
        if (stopwatch.elapsed > const Duration(seconds: 10)) {
          throw StateError('Image decoding did not complete');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    var draft = container.read(imageDraftProvider(editor.draftKey));
    expect(
      draft.images.map((i) => i.name),
      ['image.png', 'image.jpg'],
      reason: '${draft.error}; reading=${draft.reading}',
    );
    final jpgId = draft.images.last.id;
    await tester.ensureVisible(find.byKey(ValueKey('left-$jpgId')));
    await tester.tap(find.byKey(ValueKey('left-$jpgId')));
    await tester.pumpAndSettle();
    expect(
      container.read(imageDraftProvider(editor.draftKey)).images.first.id,
      jpgId,
    );
    final drop = tester.widget<DropTarget>(find.byType(DropTarget));
    await tester.runAsync(() async {
      drop.onDragDone!(
        DropDoneDetails(
          files: [DropItemFile('test/fixtures/image.webp', name: 'image.webp')],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      final stopwatch = Stopwatch()..start();
      while (container.read(imageDraftProvider(editor.draftKey)).reading) {
        if (stopwatch.elapsed > const Duration(seconds: 10)) {
          throw StateError('Dropped image decoding did not complete');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    draft = container.read(imageDraftProvider(editor.draftKey));
    expect(draft.images.length, 3);
    await tester.ensureVisible(
      find.byKey(ValueKey('remove-${draft.images.last.id}')),
    );
    await tester.tap(find.byKey(ValueKey('remove-${draft.images.last.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), '画像付き商品');
    await tester.enterText(find.byType(TextFormField).at(2), '1000');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('商品を登録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('商品を登録'));
    await tester.pumpAndSettle();
    final saved =
        (await container.read(repositoryProvider).loadProducts('demo')).single;
    expect(saved.images.length, 2);
    expect(saved.images.first.id, jpgId);
    expect(
      tester.widget<ProductImageView>(find.byType(ProductImageView)).image!.id,
      jpgId,
    );
    // Visibility changes must not discard images.
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      (await container.read(repositoryProvider).loadProducts('demo'))
          .single
          .images
          .length,
      2,
    );
    container.read(routerProvider).go('/admin/products/${saved.id}/edit');
    await tester.pumpAndSettle();
    final edit = tester.widget<ProductImageEditor>(
      find.byType(ProductImageEditor),
    );
    expect(
      container.read(imageDraftProvider(edit.draftKey)).images.first.id,
      jpgId,
    );
    await tester.ensureVisible(find.text('変更を保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('変更を保存'));
    await tester.pumpAndSettle();
    expect(
      (await container.read(repositoryProvider).loadProducts('demo'))
          .single
          .images
          .length,
      2,
    );
  });
  testWidgets('gallery switches main images and handles no images on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: [image('a'), image('b')],
            height: 200,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-a')), findsOneWidget);
    await tester.tap(find.byTooltip('2枚目を表示'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-b')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ProductImageGallery(images: [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductImageView), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });
  testWidgets('public shop shows ordered main images and gallery selection', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repository = container.read(repositoryProvider);
    await repository.saveShop(
      const Shop(id: 'demo', name: '画像テスト店舗', description: '', slug: 'images'),
    );
    await container
        .read(productImageServiceProvider)
        .save(product([image('a'), image('b')]));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ShopHubApp(),
      ),
    );
    container.read(routerProvider).go('/shop/images');
    await tester.pumpAndSettle();
    expect(
      tester.widget<ProductImageView>(find.byType(ProductImageView)).image!.id,
      'a',
    );
    container.read(routerProvider).go('/shop/images/products/p1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('2枚目を表示'));
    await tester.tap(find.byTooltip('2枚目を表示'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('main-b')), findsOneWidget);
  });
  testWidgets(
    'mobile editor displays images and supports arrow reorder and removal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(productImageServiceProvider)
          .save(product([image('a'), image('b'), image('c')]));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShopHubApp(),
        ),
      );
      container.read(routerProvider).go('/admin/products/p1/edit');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('left-b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('left-b')));
      await tester.pumpAndSettle();
      final editor = tester.widget<ProductImageEditor>(
        find.byType(ProductImageEditor),
      );
      expect(
        container.read(imageDraftProvider(editor.draftKey)).images.first.id,
        'b',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('remove-c')));
      await tester.tap(find.byKey(const ValueKey('remove-c')));
      await tester.pumpAndSettle();
      expect(
        container.read(imageDraftProvider(editor.draftKey)).images.length,
        2,
      );
      expect(tester.takeException(), isNull);
      container.read(routerProvider).go('/admin/products');
      await tester.pumpAndSettle();
      expect(
        (await container.read(repositoryProvider).loadProducts('demo'))
            .single
            .images
            .map((i) => i.id),
        ['a', 'b', 'c'],
      );
    },
  );
}

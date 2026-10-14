import '../../models/product_image.dart';
import '../../models/shop_models.dart';
import '../shop_repository.dart';
import 'image_storage.dart';

class PendingImageCleanup {
  PendingImageCleanup(this.shopId, this.productId, List<ProductImage> images)
    : images = List.unmodifiable(images);
  final String shopId, productId;
  final List<ProductImage> images;
}

class ProductImageService {
  ProductImageService(this.repository, this.storage);
  final ShopRepository repository;
  final ProductImageStorage storage;
  final _pendingCleanup = <PendingImageCleanup>[];
  List<PendingImageCleanup> get pendingCleanup =>
      List.unmodifiable(_pendingCleanup);

  /// Returns a warning only if metadata was saved but obsolete image cleanup
  /// failed. Never describe an already saved product as an unsuccessful save.
  Future<String?> save(
    Product product, {
    void Function(double)? onProgress,
  }) async {
    final existing = (await repository.loadProducts(
      product.shopId,
    )).where((p) => p.id == product.id);
    final previous = existing.isEmpty
        ? <ProductImage>[]
        : existing.first.images;
    final images = await storage.save(
      product.shopId,
      product.id,
      product.images,
      onProgress: onProgress,
    );
    try {
      await repository.saveProduct(product.withImages(images));
    } catch (_) {
      final oldPaths = previous.map((i) => i.storagePath).toSet();
      final created = images
          .where(
            (i) => i.storagePath != null && !oldPaths.contains(i.storagePath),
          )
          .toList();
      try {
        await storage.delete(product.shopId, product.id, created);
      } catch (_) {
        _pendingCleanup.add(
          PendingImageCleanup(product.shopId, product.id, created),
        );
      }
      rethrow;
    }
    final retained = images.map((image) => image.id).toSet();
    final removed = previous
        .where((image) => !retained.contains(image.id))
        .toList();
    try {
      await storage.delete(product.shopId, product.id, removed);
    } catch (_) {
      _pendingCleanup.add(
        PendingImageCleanup(product.shopId, product.id, removed),
      );
      return '商品は保存しましたが、一部の画像削除が未完了です。';
    }
    return null;
  }

  Future<void> delete(Product product) async {
    // Preserve the product metadata if Storage cleanup fails, allowing retry.
    await storage.delete(product.shopId, product.id, product.images);
    await repository.deleteProduct(product.shopId, product.id);
  }

  Future<void> retryPendingCleanup() async {
    for (final task in [..._pendingCleanup]) {
      await storage.delete(task.shopId, task.productId, task.images);
      _pendingCleanup.remove(task);
    }
  }
}

import '../models/shop_models.dart';

/// Firestore implementations can use shops/{shopId}/products and orders.
/// Mock operations never write to Firebase. URL uniqueness belongs here so a
/// future backend can enforce it atomically rather than trusting a UI check.
abstract class ShopRepository {
  Future<Shop> loadShop(String shopId);
  Future<List<Product>> loadProducts(String shopId);
  Future<List<ShopOrder>> loadOrders(String shopId);
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String shopId, String productId);
  Future<void> saveShop(Shop shop);
  Future<bool> isSlugAvailable(String slug, String excludingShopId);
}

class MockShopRepository implements ShopRepository {
  final _shops = <String, Shop>{
    'demo': const Shop(
      id: 'demo',
      name: '',
      description: '',
      slug: 'shop',
      published: false,
    ),
  };
  final _products = <Product>[];
  final _orders = <ShopOrder>[];
  @override
  Future<Shop> loadShop(String shopId) async =>
      _shops[shopId] ?? (throw StateError('ショップが見つかりません'));
  @override
  Future<List<Product>> loadProducts(String shopId) async =>
      _products.where((p) => p.shopId == shopId).toList();
  @override
  Future<List<ShopOrder>> loadOrders(String shopId) async =>
      _orders.where((o) => o.shopId == shopId).toList();
  @override
  Future<void> saveProduct(Product product) async {
    if (product.name.trim().isEmpty || product.price < 0 || product.stock < 0) {
      throw ArgumentError('商品情報が正しくありません');
    }
    _products.removeWhere(
      (p) => p.id == product.id && p.shopId == product.shopId,
    );
    _products.add(product.withImages(product.images));
  }

  @override
  Future<void> deleteProduct(String shopId, String productId) async =>
      _products.removeWhere((p) => p.id == productId && p.shopId == shopId);
  @override
  Future<bool> isSlugAvailable(String slug, String excludingShopId) async =>
      !_shops.values.any((s) => s.id != excludingShopId && s.slug == slug);
  @override
  Future<void> saveShop(Shop shop) async {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(shop.slug) ||
        shop.name.trim().isEmpty) {
      throw ArgumentError('ショップ情報が正しくありません');
    }
    if (!await isSlugAvailable(shop.slug, shop.id)) {
      throw StateError('このURL用IDは使用されています');
    }
    _shops[shop.id] = shop;
  }
}

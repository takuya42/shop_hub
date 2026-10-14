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
      name: '暮らしのアトリエ',
      description: '日々の暮らしに、小さなときめきを。\n作り手の想いがつまった、長く愛せるものをお届けします。',
      slug: 'atelier',
    ),
  };
  final _products = <Product>[
    const Product(
      id: 'p1',
      shopId: 'demo',
      name: 'キャンバストートバッグ',
      description: '丈夫な帆布で仕立てた、毎日に寄り添うトートバッグ。A4サイズが入り、通勤にもお買い物にも使えます。',
      price: 3800,
      stock: 12,
    ),
    const Product(
      id: 'p2',
      shopId: 'demo',
      name: '手仕事のセラミックマグ',
      description: 'ひとつずつ手で釉薬をかけた、あたたかな表情のマグカップ。容量約300ml。',
      price: 2400,
      stock: 8,
    ),
    const Product(
      id: 'p3',
      shopId: 'demo',
      name: 'リネンのエプロン',
      description: '使うほどにやわらかくなる天然リネン。料理や庭仕事の時間を心地よく。',
      price: 5200,
      stock: 0,
    ),
    const Product(
      id: 'p4',
      shopId: 'demo',
      name: '季節のポストカードセット',
      description: '季節の草花を描いた5枚セット。大切な人へのお便りに。',
      price: 900,
      stock: 20,
      published: false,
    ),
  ];
  late final _orders = <ShopOrder>[
    ShopOrder(
      id: 'SH-1003',
      shopId: 'demo',
      date: DateTime.now().subtract(const Duration(hours: 3)),
      status: '受付済み',
      lines: const [OrderLine('キャンバストートバッグ', 1, 3800)],
    ),
    ShopOrder(
      id: 'SH-1002',
      shopId: 'demo',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: '完了',
      lines: const [OrderLine('手仕事のセラミックマグ', 2, 2400)],
    ),
    ShopOrder(
      id: 'SH-1001',
      shopId: 'demo',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: 'キャンセル',
      lines: const [OrderLine('リネンのエプロン', 1, 5200)],
    ),
  ];
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
    _products.add(product);
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

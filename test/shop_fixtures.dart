import 'package:shop_hub/data/shop_repository.dart';
import 'package:shop_hub/models/shop_models.dart';

// Test data is explicitly created by tests; the application starts empty.
Future<void> seedShop(ShopRepository repository) async {
  await repository.saveShop(
    const Shop(
      id: 'demo',
      name: 'テストショップ',
      description: '検証用の説明',
      slug: 'test-shop',
    ),
  );
  await repository.saveProduct(
    const Product(
      id: 'p1',
      shopId: 'demo',
      name: '公開商品',
      description: '検証用の商品説明',
      price: 1000,
      stock: 2,
    ),
  );
  await repository.saveProduct(
    const Product(
      id: 'p4',
      shopId: 'demo',
      name: '非公開商品',
      description: '',
      price: 1000,
      stock: 2,
      published: false,
    ),
  );
}

List<ShopOrder> get testOrders => [
  ShopOrder(
    id: 'TEST-ORDER',
    shopId: 'demo',
    date: DateTime(2026, 1, 1),
    status: '受付済み',
    lines: const [OrderLine('公開商品', 1, 1000)],
  ),
];

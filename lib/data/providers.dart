import 'images/image_storage.dart';
import 'images/product_image_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_models.dart';
import 'shop_repository.dart';

final repositoryProvider = Provider<ShopRepository>(
  (ref) => MockShopRepository(),
);
final shopProvider = FutureProvider.family<Shop, String>(
  (ref, id) => ref.watch(repositoryProvider).loadShop(id),
);
final productsProvider = FutureProvider.family<List<Product>, String>(
  (ref, id) => ref.watch(repositoryProvider).loadProducts(id),
);
final ordersProvider = FutureProvider.family<List<ShopOrder>, String>(
  (ref, id) => ref.watch(repositoryProvider).loadOrders(id),
);
final publicShopProvider = FutureProvider.family<Shop?, String>((
  ref,
  slug,
) async {
  // A Firestore adapter can resolve URL IDs through a dedicated slug index.
  final shop = await ref.watch(shopProvider('demo').future);
  return shop.slug == slug ? shop : null;
});

String yen(int value) =>
    '¥${value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';
String orderDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

final productImageServiceProvider = Provider<ProductImageService>(
  (ref) => ProductImageService(
    ref.watch(repositoryProvider),
    ref.watch(imageStorageProvider),
  ),
);

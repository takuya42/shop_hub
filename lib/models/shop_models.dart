import 'product_image.dart';

class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    required this.stock,
    this.published = true,
    this.images = const [],
  });
  final String id, shopId, name, description;
  final int price, stock;
  final bool published;
  final List<ProductImage> images;
  Product withImages(List<ProductImage> value) => Product(
    id: id,
    shopId: shopId,
    name: name,
    description: description,
    price: price,
    stock: stock,
    published: published,
    images: List.unmodifiable(value),
  );
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.description,
    required this.slug,
    this.published = true,
  });
  final String id, name, description, slug;
  final bool published;
}

class OrderLine {
  const OrderLine(this.name, this.quantity, this.unitPrice);
  final String name;
  final int quantity, unitPrice;
  int get total => quantity * unitPrice;
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.shopId,
    required this.date,
    required this.status,
    required this.lines,
  });
  final String id, shopId, status;
  final DateTime date;
  final List<OrderLine> lines;
  int get total => lines.fold(0, (sum, line) => sum + line.total);
}

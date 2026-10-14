import 'dart:typed_data';

class ProductImage {
  ProductImage.local({
    required this.id,
    required this.name,
    required this.contentType,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
       url = null,
       storagePath = null;
  const ProductImage.remote({
    required this.id,
    required this.name,
    required this.contentType,
    required String this.url,
    required String this.storagePath,
  }) : bytes = null;
  final String id, name, contentType;
  final Uint8List? bytes;
  final String? url, storagePath;
}

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product_image.dart';
import 'image_draft.dart';

class ImageStorageException implements Exception {
  const ImageStorageException(this.message, {this.pendingPaths = const []});
  final String message;
  final List<String> pendingPaths;
}

abstract class ProductImageStorage {
  bool get remoteEnabled;
  Future<List<ProductImage>> save(
    String shopId,
    String productId,
    List<ProductImage> images, {
    void Function(double progress)? onProgress,
  });
  Future<void> delete(
    String shopId,
    String productId,
    List<ProductImage> images,
  );
}

/// No authentication/ownership-verification endpoint exists in this app yet.
/// Never instantiate Firebase clients or issue Storage writes in this mode.
final imageStorageProvider = Provider<ProductImageStorage>(
  (ref) => const DeferredImageStorage(),
);

class DeferredImageStorage implements ProductImageStorage {
  const DeferredImageStorage();
  @override
  bool get remoteEnabled => false;
  @override
  Future<List<ProductImage>> save(
    String shopId,
    String productId,
    List<ProductImage> images, {
    void Function(double)? onProgress,
  }) async {
    if (images.length > maxProductImages) {
      throw const ImageStorageException('画像は最大5枚です。');
    }
    for (final image in images) {
      productImagePath(shopId, productId, image);
      if (image.bytes != null &&
          (image.bytes!.length > maxImageBytes ||
              imageContentType(image.bytes!) != image.contentType)) {
        throw const ImageStorageException('画像の形式またはサイズが正しくありません。');
      }
    }
    return List.unmodifiable(images);
  }

  @override
  Future<void> delete(
    String shopId,
    String productId,
    List<ProductImage> images,
  ) async {
    if (images.any((image) => image.storagePath != null)) {
      throw const ImageStorageException('クラウド画像の削除は保留中です。権限確認後に再試行してください。');
    }
  }
}

String productImagePath(String shopId, String productId, ProductImage image) {
  for (final segment in [shopId, productId, image.id]) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(segment)) {
      throw const ImageStorageException('画像の保存先が正しくありません。');
    }
  }
  final extension = switch (image.contentType) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => throw const ImageStorageException('未対応の画像形式です。'),
  };
  return 'shops/$shopId/products/$productId/images/${image.id}.$extension';
}

/// Future integration only: requires a signed-in non-anonymous user and an
/// injected server-backed ownership verifier. Storage Rules must independently
/// enforce ownership. A client callback is not a substitute for those rules.
/// This adapter is deliberately NOT connected to imageStorageProvider.
class FirebaseProductImageStorage implements ProductImageStorage {
  FirebaseProductImageStorage({
    required this.ownsShop,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _storage = storage,
       _auth = auth;
  final Future<bool> Function(String uid, String shopId) ownsShop;
  final FirebaseStorage? _storage;
  final FirebaseAuth? _auth;
  FirebaseStorage get storage => _storage ?? FirebaseStorage.instance;
  @override
  bool get remoteEnabled => true;
  Future<void> authorize(String shopId, String productId) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(shopId) ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(productId)) {
      throw const ImageStorageException('画像の保存先が正しくありません。');
    }
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || user.isAnonymous || !await ownsShop(user.uid, shopId)) {
      throw const ImageStorageException('画像を保存する権限が確認できません。');
    }
  }

  void validate(String shopId, String productId, ProductImage image) {
    final path = productImagePath(shopId, productId, image);
    if (image.storagePath != null && image.storagePath != path) {
      throw const ImageStorageException('他の商品に属する画像は操作できません。');
    }
    final bytes = image.bytes;
    if (bytes != null &&
        (bytes.length > maxImageBytes ||
            imageContentType(bytes) != image.contentType)) {
      throw const ImageStorageException('画像の形式またはサイズが正しくありません。');
    }
  }

  @override
  Future<List<ProductImage>> save(
    String shopId,
    String productId,
    List<ProductImage> images, {
    void Function(double)? onProgress,
  }) async {
    await authorize(shopId, productId);
    if (images.length > maxProductImages) {
      throw const ImageStorageException('画像は最大5枚です。');
    }
    for (final image in images) {
      validate(shopId, productId, image);
    }
    final created = <String>[];
    final result = <ProductImage>[];
    final total = images.fold<int>(
      0,
      (sum, image) => sum + (image.bytes?.length ?? 0),
    );
    var completed = 0;
    try {
      for (final image in images) {
        final bytes = image.bytes;
        if (bytes == null) {
          result.add(image);
          continue;
        }
        final path = productImagePath(shopId, productId, image);
        final reference = storage.ref(path);
        // Include partially written objects in rollback cleanup.
        created.add(path);
        final upload = reference.putData(
          bytes,
          SettableMetadata(contentType: image.contentType),
        );
        final subscription = upload.snapshotEvents.listen((snapshot) {
          onProgress?.call(
            total == 0
                ? 1
                : ((completed + snapshot.bytesTransferred) / total).clamp(0, 1),
          );
        }, onError: (Object _) {});
        try {
          await upload;
        } finally {
          await subscription.cancel();
        }
        final url = await reference.getDownloadURL();
        completed += bytes.length;
        result.add(
          ProductImage.remote(
            id: image.id,
            name: image.name,
            contentType: image.contentType,
            url: url,
            storagePath: path,
          ),
        );
      }
      onProgress?.call(1);
      return List.unmodifiable(result);
    } catch (_) {
      final pending = <String>[];
      for (final path in created) {
        try {
          await deletePath(path);
        } catch (_) {
          pending.add(path);
        }
      }
      throw ImageStorageException(
        pending.isEmpty
            ? '画像を保存できませんでした。接続や権限を確認して再試行してください。'
            : '画像の保存に失敗し、一部の画像を削除できませんでした。管理者による確認が必要です。',
        pendingPaths: List.unmodifiable(pending),
      );
    }
  }

  Future<void> deletePath(String path) async {
    try {
      await storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }

  @override
  Future<void> delete(
    String shopId,
    String productId,
    List<ProductImage> images,
  ) async {
    final remote = images.where((image) => image.storagePath != null).toList();
    if (remote.isEmpty) return;
    await authorize(shopId, productId);
    for (final image in remote) {
      validate(shopId, productId, image);
    }
    final pending = <String>[];
    for (final image in remote) {
      try {
        await deletePath(image.storagePath!);
      } catch (_) {
        pending.add(image.storagePath!);
      }
    }
    if (pending.isNotEmpty) {
      throw ImageStorageException(
        '画像を削除できませんでした。再試行してください。',
        pendingPaths: List.unmodifiable(pending),
      );
    }
  }
}

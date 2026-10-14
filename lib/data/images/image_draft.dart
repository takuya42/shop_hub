import 'dart:math';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/product_image.dart';
import 'selected_file_resources.dart';

void releaseSelectedFiles(Iterable<XFile> files) {
  for (final file in files) {
    releaseSelectedFile(file.path);
  }
}

const maxProductImages = 5;
const maxImageBytes = 5 * 1024 * 1024;
const imageTypes = XTypeGroup(
  label: '商品画像',
  extensions: ['jpg', 'jpeg', 'png', 'webp'],
  mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
);
final imagePickerProvider = Provider<Future<List<XFile>> Function()>(
  (ref) =>
      () => openFiles(acceptedTypeGroups: [imageTypes]),
);

class ImageDraftKey {
  ImageDraftKey([List<ProductImage> images = const []])
    : initial = List.unmodifiable(images);
  final List<ProductImage> initial;
}

class ImageDraftState {
  ImageDraftState({
    List<ProductImage> images = const [],
    this.reading = false,
    this.progress = 0,
    this.error,
  }) : images = List.unmodifiable(images);
  final List<ProductImage> images;
  final bool reading;
  final double progress;
  final String? error;
}

final imageDraftProvider = NotifierProvider.autoDispose
    .family<ImageDraftController, ImageDraftState, ImageDraftKey>(
      ImageDraftController.new,
    );

String? imageContentType(List<int> bytes) {
  bool starts(List<int> signature) =>
      bytes.length >= signature.length &&
      List.generate(
        signature.length,
        (i) => bytes[i] == signature[i],
      ).every((v) => v);
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (starts([82, 73, 70, 70]) &&
      bytes.length >= 12 &&
      bytes[8] == 87 &&
      bytes[9] == 69 &&
      bytes[10] == 66 &&
      bytes[11] == 80) {
    return 'image/webp';
  }
  return null;
}

class ImageDraftController extends Notifier<ImageDraftState> {
  ImageDraftController(this.key);
  final ImageDraftKey key;
  @override
  ImageDraftState build() => ImageDraftState(images: key.initial);
  void reportError(String message) {
    if (!state.reading) {
      state = ImageDraftState(images: state.images, error: message);
    }
  }

  Future<void> addFiles(List<XFile> files) async {
    if (state.reading || files.isEmpty) {
      releaseSelectedFiles(files);
      return;
    }
    if (state.images.length + files.length > maxProductImages) {
      reportError('画像は1商品につき最大5枚です。');
      releaseSelectedFiles(files);
      return;
    }
    final original = state.images;
    state = ImageDraftState(images: original, reading: true);
    try {
      final added = <ProductImage>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final extension = file.name.toLowerCase().split('.').last;
        final expected = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => null,
        };
        if (expected == null) {
          throw const FormatException('JPEG・PNG・WebPの画像を選択してください。');
        }
        if (await file.length() > maxImageBytes) {
          throw const FormatException('画像は1枚あたり5MB以下にしてください。');
        }
        if (!ref.mounted) return;
        final bytes = await file.readAsBytes();
        if (bytes.length > maxImageBytes) {
          throw const FormatException('画像は1枚あたり5MB以下にしてください。');
        }
        if (imageContentType(bytes) != expected) {
          throw const FormatException('拡張子と画像形式が一致しないか、画像が破損しています。');
        }
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 32,
          targetHeight: 32,
          allowUpscaling: false,
        );
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
        if (!ref.mounted) return;
        final random = Random.secure();
        final id = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        added.add(
          ProductImage.local(
            id: id,
            name: file.name,
            contentType: expected,
            bytes: bytes,
          ),
        );
        state = ImageDraftState(
          images: original,
          reading: true,
          progress: (i + 1) / files.length,
        );
      }
      if (ref.mounted) state = ImageDraftState(images: [...original, ...added]);
    } on FormatException catch (error) {
      if (ref.mounted) {
        state = ImageDraftState(images: original, error: error.message);
      }
    } catch (_) {
      if (ref.mounted) {
        state = ImageDraftState(
          images: original,
          error: '画像を読み込めませんでした。ファイルが有効か確認して再試行してください。',
        );
      }
    } finally {
      releaseSelectedFiles(files);
    }
  }

  void remove(String id) {
    if (!state.reading) {
      state = ImageDraftState(
        images: state.images.where((image) => image.id != id).toList(),
      );
    }
  }

  /// The target is the final index, matching both arrow buttons and drag reorder.
  void move(int from, int to) {
    if (state.reading ||
        from < 0 ||
        to < 0 ||
        from >= state.images.length ||
        to >= state.images.length ||
        from == to) {
      return;
    }
    final images = [...state.images];
    images.insert(to, images.removeAt(from));
    state = ImageDraftState(images: images);
  }
}

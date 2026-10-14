import 'package:flutter/material.dart';
import '../models/product_image.dart';
import 'common.dart';

class ProductImageView extends StatelessWidget {
  const ProductImageView({super.key, required this.image, this.height = 180});
  final ProductImage? image;
  final double height;
  @override
  Widget build(BuildContext context) {
    final value = image;
    if (value == null) return ImagePlaceholder(height: height);
    final cacheLimit = (height * MediaQuery.devicePixelRatioOf(context) * 2)
        .ceil()
        .clamp(64, 1600)
        .toInt();
    final ImageProvider provider = value.bytes != null
        ? MemoryImage(value.bytes!)
        : NetworkImage(value.url!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: ColoredBox(
        color: const Color(0xFFF1F5F9),
        child: Image(
          image: ResizeImage(
            provider,
            width: cacheLimit,
            height: cacheLimit,
            policy: ResizeImagePolicy.fit,
          ),
          width: double.infinity,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: value.name,
          errorBuilder: (_, _, _) => SizedBox(
            height: height,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.blueGrey),
            ),
          ),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : SizedBox(
                  height: height,
                  child: const Center(child: CircularProgressIndicator()),
                ),
        ),
      ),
    );
  }
}

class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    super.key,
    required this.images,
    this.height = 360,
  });
  final List<ProductImage> images;
  final double height;
  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return ImagePlaceholder(height: widget.height);
    final matching = widget.images.where((image) => image.id == selected);
    final main = matching.isEmpty ? widget.images.first : matching.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProductImageView(
          key: ValueKey('main-${main.id}'),
          image: main,
          height: widget.height,
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                Semantics(
                  button: true,
                  selected: widget.images[i].id == main.id,
                  label: '${i + 1}枚目を表示',
                  child: Tooltip(
                    message: '${i + 1}枚目を表示',
                    child: InkWell(
                      onTap: () =>
                          setState(() => selected = widget.images[i].id),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.images[i].id == main.id
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ExcludeSemantics(
                          child: ProductImageView(
                            image: widget.images[i],
                            height: 60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

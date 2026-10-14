import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/images/image_draft.dart';
import '../data/images/image_storage.dart';
import 'product_form_widgets.dart';
import 'product_images.dart';

class ProductImageEditor extends ConsumerStatefulWidget {
  const ProductImageEditor({
    super.key,
    required this.draftKey,
    this.disabled = false,
  });
  final ImageDraftKey draftKey;
  final bool disabled;
  @override
  ConsumerState<ProductImageEditor> createState() => _ProductImageEditorState();
}

class _ProductImageEditorState extends ConsumerState<ProductImageEditor> {
  bool hovering = false, picking = false;
  ImageDraftController get controller =>
      ref.read(imageDraftProvider(widget.draftKey).notifier);
  Future<void> select() async {
    if (picking || widget.disabled) return;
    setState(() => picking = true);
    try {
      final files = await ref.read(imagePickerProvider)();
      if (mounted && !widget.disabled) {
        await controller.addFiles(files);
      } else {
        releaseSelectedFiles(files);
      }
    } catch (_) {
      if (mounted) controller.reportError('画像を選択できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> dropped(List<XFile> files) async {
    setState(() => hovering = false);
    if (!widget.disabled) await controller.addFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(imageDraftProvider(widget.draftKey));
    final disabled = widget.disabled || draft.reading || picking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropTarget(
          enable: !disabled && draft.images.length < maxProductImages,
          onDragEntered: (_) => setState(() => hovering = true),
          onDragExited: (_) => setState(() => hovering = false),
          onDragDone: (details) => dropped(details.files),
          child: ProductImageInput(
            disabled: disabled || draft.images.length == maxProductImages,
            highlighted: hovering,
            onSelect: select,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${draft.images.length}/5枚 · 1枚目がメイン画像です',
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
        ),
        if (!ref.watch(imageStorageProvider).remoteEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'クラウド保存は保留中です。画像はこのタブで起動中のみ保持され、再読み込みで消えます。',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        if (draft.reading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: draft.progress),
                const SizedBox(height: 6),
                const Text('画像を読み込み中…', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        if (draft.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                draft.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        if (draft.images.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '画像をドラッグ（スマートフォンは長押し）するか、矢印で順番を変更できます。',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < draft.images.length; i++)
                imageTile(i, disabled),
            ],
          ),
        ],
      ],
    );
  }

  Widget imageTile(int index, bool disabled) {
    final images = ref.watch(imageDraftProvider(widget.draftKey)).images;
    final image = images[index];
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) =>
          !disabled &&
          details.data != image.id &&
          images.any((i) => i.id == details.data),
      onAcceptWithDetails: (details) => controller.move(
        images.indexWhere((i) => i.id == details.data),
        index,
      ),
      builder: (context, candidates, rejected) {
        final tile = Container(
          key: ValueKey('image-${image.id}'),
          width: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: candidates.isNotEmpty
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE2E8F0),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              ProductImageView(image: image, height: 100),
              const SizedBox(height: 6),
              Text(
                index == 0 ? 'メイン' : '${index + 1}枚目',
                style: TextStyle(
                  color: index == 0 ? const Color(0xFF2563EB) : Colors.blueGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                image.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: ValueKey('left-${image.id}'),
                    tooltip: '前へ',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: disabled || index == 0
                        ? null
                        : () => controller.move(index, index - 1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  IconButton(
                    key: ValueKey('right-${image.id}'),
                    tooltip: '後ろへ',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: disabled || index == images.length - 1
                        ? null
                        : () => controller.move(index, index + 1),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  IconButton(
                    key: ValueKey('remove-${image.id}'),
                    tooltip: '画像を削除',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: disabled
                        ? null
                        : () => controller.remove(image.id),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        );
        final feedback = Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 140,
            child: ProductImageView(image: image, height: 110),
          ),
        );
        final ghost = Container(
          width: 140,
          height: 200,
          color: const Color(0xFF2563EB).withValues(alpha: 0.06),
        );
        return MediaQuery.sizeOf(context).width < 600
            ? LongPressDraggable<String>(
                data: image.id,
                maxSimultaneousDrags: disabled ? 0 : 1,
                feedback: feedback,
                childWhenDragging: ghost,
                child: tile,
              )
            : Draggable<String>(
                data: image.id,
                maxSimultaneousDrags: disabled ? 0 : 1,
                feedback: feedback,
                childWhenDragging: ghost,
                child: tile,
              );
      },
    );
  }
}

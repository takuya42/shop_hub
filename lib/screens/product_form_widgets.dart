import 'package:flutter/material.dart';
import '../data/providers.dart';
import 'common.dart';

/// Keep labels separate from controls while preserving accessible field labels.
class ProductFormRow extends StatelessWidget {
  const ProductFormRow({
    super.key,
    required this.label,
    required this.child,
    this.requiredField = false,
    this.last = false,
  });
  final String label;
  final Widget child;
  final bool requiredField, last;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= 660;
      final control = Semantics(label: label, child: child);
      final heading = Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          if (requiredField)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '必須',
                style: TextStyle(fontSize: 10, color: Color(0xFF2563EB)),
              ),
            ),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFEDF0F4))),
        ),
        child: horizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 164,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, right: 20),
                      child: heading,
                    ),
                  ),
                  Expanded(child: control),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 14), control],
              ),
      );
    },
  );
}

class ProductImageInput extends StatelessWidget {
  const ProductImageInput({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _DashedBorder(),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 30,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '商品の魅力が伝わる画像を追加',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                showMessage(context, '画像アップロードは準備中です。現在は画像を保存しません。'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('画像を選択'),
          ),
          const SizedBox(height: 12),
          const Text(
            '画像アップロードは準備中です',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        ).deflate(1),
      );
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 11) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 6).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder oldDelegate) => false;
}

Future<void> showProductPreview(
  BuildContext context, {
  required String name,
  required String description,
  required int price,
  required int stock,
  required bool published,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('商品プレビュー'),
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '保存前の内容を確認できます。',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 18),
          const ImagePlaceholder(height: 220),
          const SizedBox(height: 20),
          Text(name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(yen(price), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(stock == 0 ? '在庫なし' : '在庫 $stock点'),
          const SizedBox(height: 12),
          Chip(label: Text(published ? '公開' : '非公開')),
          const SizedBox(height: 14),
          Text(
            description.isEmpty ? '商品説明は未入力です' : description,
            style: const TextStyle(height: 1.7),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('編集に戻る'),
      ),
    ],
  ),
);

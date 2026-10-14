import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.retry,
  });
  final AsyncValue<T> value;
  final Widget Function(T) builder;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CircularProgressIndicator()),
    ),
    error: (_, _) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('データを読み込めませんでした'),
          TextButton(onPressed: retry, child: const Text('再試行')),
        ],
      ),
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Wrap(
      spacing: 24,
      runSpacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.blueGrey)),
          ],
        ),
        ?action,
      ],
    ),
  );
}

class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key, this.height = 180});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFEDF2FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(
      child: Icon(Icons.image_outlined, size: 48, color: Color(0xFF94A3B8)),
    ),
  );
}

void showMessage(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('商品を削除しますか？'),
        content: Text('「$name」を削除します。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    ) ??
    false;

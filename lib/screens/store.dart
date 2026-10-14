import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers.dart';
import '../models/shop_models.dart';
import 'common.dart';

class StorePage extends ConsumerStatefulWidget {
  const StorePage({super.key, required this.slug, this.productId});
  final String slug;
  final String? productId;
  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text(
        'shop_hub',
        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
      ),
      actions: [
        TextButton(
          onPressed: () => context.go('/admin'),
          child: const Text('管理画面'),
        ),
        const SizedBox(width: 16),
      ],
    ),
    body: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AsyncView(
              value: ref.watch(publicShopProvider(widget.slug)),
              retry: () => ref.invalidate(publicShopProvider(widget.slug)),
              builder: (shop) {
                if (shop == null) {
                  return const StoreNotice('ショップが見つかりません', 'URLをご確認ください。');
                }
                if (!shop.published) {
                  return const StoreNotice(
                    'ただいま準備中です',
                    'このショップは現在非公開です。公開までお待ちください。',
                  );
                }
                return AsyncView(
                  value: ref.watch(productsProvider(shop.id)),
                  retry: () => ref.invalidate(productsProvider(shop.id)),
                  builder: (products) {
                    final visible = products.where((p) => p.published).toList();
                    if (widget.productId != null) {
                      final matches = visible.where(
                        (p) => p.id == widget.productId,
                      );
                      if (matches.isEmpty) {
                        return const StoreNotice(
                          '商品が見つかりません',
                          'この商品は公開されていないか、削除されています。',
                        );
                      }
                      return ProductPresentation(
                        shop: shop,
                        product: matches.first,
                      );
                    }
                    final filtered = visible
                        .where(
                          (p) => '${p.name} ${p.description}'
                              .toLowerCase()
                              .contains(query),
                        )
                        .toList();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 56,
                            horizontal: 24,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5FC),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'WELCOME TO OUR SHOP',
                                style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 3,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                shop.name,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                shop.description,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  height: 1.9,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          '商品一覧',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'お気に入りの商品を探す',
                          ),
                          onChanged: (v) =>
                              setState(() => query = v.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 24),
                        if (filtered.isEmpty)
                          const StoreNotice(
                            '商品がありません',
                            '検索条件を変えるか、商品の公開をお待ちください。',
                          )
                        else
                          LayoutBuilder(
                            builder: (context, c) {
                              final columns = c.maxWidth >= 800
                                  ? 3
                                  : c.maxWidth >= 500
                                  ? 2
                                  : 1;
                              return Wrap(
                                spacing: 20,
                                runSpacing: 20,
                                children: filtered
                                    .map(
                                      (p) => SizedBox(
                                        width:
                                            (c.maxWidth - (columns - 1) * 20) /
                                            columns,
                                        child: Card(
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: () => context.go(
                                              '/shop/${shop.slug}/products/${p.id}',
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const ImagePlaceholder(
                                                    height: 220,
                                                  ),
                                                  const SizedBox(height: 18),
                                                  Text(
                                                    p.name,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    yen(p.price),
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    p.stock == 0
                                                        ? 'SOLD OUT'
                                                        : '在庫あり · ${p.stock}点',
                                                    style: TextStyle(
                                                      color: p.stock == 0
                                                          ? Colors.grey
                                                          : Colors.blueGrey,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              );
                            },
                          ),
                        const SizedBox(height: 48),
                        const Center(
                          child: Text(
                            'Powered by shop_hub',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class StoreNotice extends StatelessWidget {
  const StoreNotice(this.title, this.message, {super.key});
  final String title, message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Center(
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 52,
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class ProductPresentation extends StatelessWidget {
  const ProductPresentation({
    super.key,
    required this.shop,
    required this.product,
  });
  final Shop shop;
  final Product product;
  @override
  Widget build(BuildContext context) {
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(shop.name, style: const TextStyle(color: Colors.blueGrey)),
        const SizedBox(height: 18),
        Text(
          product.name,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text(
          yen(product.price),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        Chip(label: Text(product.stock == 0 ? '在庫なし' : '在庫 ${product.stock}点')),
        const Divider(height: 40),
        Text(product.description, style: const TextStyle(height: 1.9)),
        const SizedBox(height: 28),
        const Text(
          '現在はショップのプレビュー版です。購入機能は準備中です。',
          style: TextStyle(color: Colors.blueGrey),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go('/shop/${shop.slug}'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('ショップトップに戻る'),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 700
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(child: ImagePlaceholder(height: 400)),
                    const SizedBox(width: 40),
                    Expanded(child: details),
                  ],
                )
              : Column(
                  children: [
                    const ImagePlaceholder(height: 280),
                    const SizedBox(height: 28),
                    details,
                  ],
                ),
        ),
      ],
    );
  }
}

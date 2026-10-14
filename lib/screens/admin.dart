import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/providers.dart';
import '../models/shop_models.dart';
import 'common.dart';

const demoShopId = 'demo';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    Widget menu() => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'shop_hub',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const Text('ショップ管理', style: TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 24),
            for (final item in [
              (Icons.space_dashboard_outlined, 'ダッシュボード', '/admin'),
              (Icons.inventory_2_outlined, '商品管理', '/admin/products'),
              (Icons.receipt_long_outlined, '注文管理', '/admin/orders'),
              (Icons.tune, 'ショップ設定', '/admin/settings'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: item.$3 == '/admin'
                      ? path == '/admin'
                      : path.startsWith(item.$3),
                  selectedTileColor: const Color(0xFFEAF1FF),
                  leading: Icon(item.$1),
                  title: Text(item.$2),
                  onTap: () {
                    if (!wide) Navigator.pop(context);
                    context.go(item.$3);
                  },
                ),
              ),
            const Spacer(),
            const Text(
              'デモワークスペース',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'データは起動中のみ保存されます。\n注文はサンプルデータです。',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
    final shop = ref.watch(shopProvider(demoShopId)).asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          shop?.name ?? 'ショップ管理',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          if (shop != null)
            TextButton.icon(
              onPressed: () => context.go('/shop/${shop.slug}'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('ショップを見る'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: wide ? null : Drawer(child: menu()),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 250,
              child: ColoredBox(color: Colors.white, child: menu()),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading('ダッシュボード', 'ショップの状況を、ひと目で確認。'),
      AsyncView(
        value: ref.watch(shopProvider(demoShopId)),
        retry: () => ref.invalidate(shopProvider(demoShopId)),
        builder: (shop) => Card(
          child: ListTile(
            leading: Icon(
              shop.published
                  ? Icons.check_circle_outline
                  : Icons.visibility_off_outlined,
              color: Colors.blue,
            ),
            title: Text(shop.published ? 'ショップは公開中です' : 'ショップは非公開です'),
            subtitle: const Text('公開状態はショップ設定から変更できます'),
            trailing: TextButton(
              onPressed: () => context.go('/admin/settings'),
              child: const Text('設定'),
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      AsyncView(
        value: ref.watch(productsProvider(demoShopId)),
        retry: () => ref.invalidate(productsProvider(demoShopId)),
        builder: (products) => AsyncView(
          value: ref.watch(ordersProvider(demoShopId)),
          retry: () => ref.invalidate(ordersProvider(demoShopId)),
          builder: (orders) {
            final now = DateTime.now();
            final month = orders.where(
              (o) =>
                  o.date.year == now.year &&
                  o.date.month == now.month &&
                  o.status != 'キャンセル',
            );
            final stats = [
              (
                '今月の売上（サンプル）',
                yen(month.fold<int>(0, (sum, o) => sum + o.total)),
                Icons.payments_outlined,
              ),
              ('今月の注文数（サンプル）', '${month.length}件', Icons.shopping_bag_outlined),
              ('登録商品数', '${products.length}点', Icons.inventory_2_outlined),
              (
                '公開中の商品数',
                '${products.where((p) => p.published).length}点',
                Icons.visibility_outlined,
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final columns = c.maxWidth >= 850
                        ? 4
                        : c.maxWidth >= 460
                        ? 2
                        : 1;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: stats
                          .map(
                            (s) => SizedBox(
                              width:
                                  (c.maxWidth - (columns - 1) * 12) / columns,
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(s.$3, color: Colors.blue),
                                      const SizedBox(height: 18),
                                      Text(
                                        s.$1,
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.$2,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const PageHeading('最近の注文', 'サンプルデータです。実際の注文は発生しません。'),
                OrderList(orders: orders.take(5).toList()),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});
  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        '商品管理',
        '商品を登録して、ショップを育てましょう。',
        action: FilledButton.icon(
          onPressed: () => context.go('/admin/products/new'),
          icon: const Icon(Icons.add),
          label: const Text('商品を登録'),
        ),
      ),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '商品名・説明で検索',
        ),
        onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
      ),
      const SizedBox(height: 20),
      AsyncView(
        value: ref.watch(productsProvider(demoShopId)),
        retry: () => ref.invalidate(productsProvider(demoShopId)),
        builder: (products) {
          final filtered = products
              .where(
                (p) =>
                    '${p.name} ${p.description}'.toLowerCase().contains(query),
              )
              .toList();
          if (filtered.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('該当する商品がありません')),
            );
          }
          return Column(
            children: filtered
                .map(
                  (p) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const SizedBox(
                            width: 64,
                            child: ImagePlaceholder(height: 64),
                          ),
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      context.go('/admin/products/${p.id}'),
                                  child: Text(p.name),
                                ),
                                Text('${yen(p.price)}  ·  在庫 ${p.stock}点'),
                              ],
                            ),
                          ),
                          Chip(label: Text(p.published ? '公開中' : '非公開')),
                          Switch(
                            value: p.published,
                            onChanged: (value) async {
                              try {
                                await ref
                                    .read(repositoryProvider)
                                    .saveProduct(
                                      Product(
                                        id: p.id,
                                        shopId: p.shopId,
                                        name: p.name,
                                        description: p.description,
                                        price: p.price,
                                        stock: p.stock,
                                        published: value,
                                      ),
                                    );
                                ref.invalidate(productsProvider(demoShopId));
                              } catch (_) {
                                if (context.mounted) {
                                  showMessage(context, '公開状態を変更できませんでした');
                                }
                              }
                            },
                          ),
                          IconButton(
                            tooltip: '編集',
                            onPressed: () =>
                                context.go('/admin/products/${p.id}/edit'),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: '削除',
                            onPressed: () async {
                              if (!await confirmDelete(context, p.name)) return;
                              try {
                                await ref
                                    .read(repositoryProvider)
                                    .deleteProduct(p.shopId, p.id);
                                ref.invalidate(productsProvider(demoShopId));
                                if (context.mounted) {
                                  showMessage(context, '商品を削除しました');
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  showMessage(context, '削除できませんでした');
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class ProductEditor extends ConsumerWidget {
  const ProductEditor({super.key, this.id});
  final String? id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(productsProvider(demoShopId)),
    retry: () => ref.invalidate(productsProvider(demoShopId)),
    builder: (products) {
      final matches = products.where((p) => p.id == id);
      if (id != null && matches.isEmpty) return const Text('商品が見つかりません');
      return ProductForm(
        key: ValueKey(id ?? 'new'),
        product: id == null ? null : matches.first,
      );
    },
  );
}

class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});
  final Product? product;
  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, price, stock;
  late bool published;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name);
    description = TextEditingController(text: p?.description);
    price = TextEditingController(text: p?.price.toString());
    stock = TextEditingController(text: p?.stock.toString() ?? '0');
    published = p?.published ?? false;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
    super.dispose();
  }

  String? number(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 0 || n > 999999999
        ? '0〜999999999の整数を入力してください'
        : null;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PageHeading(
        widget.product == null ? '商品を登録' : '商品を編集',
        '商品の魅力が伝わる情報を入力しましょう。',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              children: [
                const ImagePlaceholder(),
                const SizedBox(height: 12),
                const Text(
                  '画像アップロードは今後対応予定です',
                  style: TextStyle(color: Colors.blueGrey),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: name,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: '商品名'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '商品名を入力してください' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: '商品説明'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '販売価格（円）'),
                  validator: number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stock,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '在庫数'),
                  validator: number,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('商品を公開する'),
                  value: published,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => published = v),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => context.go('/admin/products'),
                      child: const Text('キャンセル'),
                    ),
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? '保存中…' : '商品を保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await ref
          .read(repositoryProvider)
          .saveProduct(
            Product(
              id:
                  widget.product?.id ??
                  'p${DateTime.now().microsecondsSinceEpoch}',
              shopId: demoShopId,
              name: name.text.trim(),
              description: description.text.trim(),
              price: int.parse(price.text),
              stock: int.parse(stock.text),
              published: published,
            ),
          );
      ref.invalidate(productsProvider(demoShopId));
      if (mounted) {
        showMessage(context, '商品を保存しました');
        context.go('/admin/products');
      }
    } catch (_) {
      if (mounted) showMessage(context, '保存できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class AdminProductDetail extends ConsumerWidget {
  const AdminProductDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(productsProvider(demoShopId)),
    retry: () => ref.invalidate(productsProvider(demoShopId)),
    builder: (products) {
      final matches = products.where((p) => p.id == id);
      if (matches.isEmpty) return const Text('商品が見つかりません');
      final p = matches.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            p.name,
            p.published ? '公開中' : '非公開',
            action: FilledButton(
              onPressed: () => context.go('/admin/products/$id/edit'),
              child: const Text('編集'),
            ),
          ),
          const ImagePlaceholder(height: 280),
          const SizedBox(height: 24),
          Text(yen(p.price), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          Text('在庫 ${p.stock}点'),
          const SizedBox(height: 20),
          Text(p.description),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.go('/admin/products'),
            child: const Text('商品一覧に戻る'),
          ),
        ],
      );
    },
  );
}

class OrderList extends StatelessWidget {
  const OrderList({super.key, required this.orders});
  final List<ShopOrder> orders;
  @override
  Widget build(BuildContext context) => orders.isEmpty
      ? const Center(child: Text('注文はありません'))
      : Column(
          children: orders
              .map(
                (o) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(o.id),
                    subtitle: Text(
                      '${orderDate(o.date)}\n${o.lines.map((l) => '${l.name} ×${l.quantity}').join('、')}',
                    ),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          yen(o.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(o.status),
                      ],
                    ),
                    onTap: () => context.go('/admin/orders/${o.id}'),
                  ),
                ),
              )
              .toList(),
        );
}

class OrdersPage extends ConsumerWidget {
  const OrdersPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading('注文管理', 'サンプル注文を表示しています。実際の注文は発生しません。'),
      AsyncView(
        value: ref.watch(ordersProvider(demoShopId)),
        retry: () => ref.invalidate(ordersProvider(demoShopId)),
        builder: (orders) => OrderList(orders: orders),
      ),
    ],
  );
}

class OrderDetail extends ConsumerWidget {
  const OrderDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(ordersProvider(demoShopId)),
    retry: () => ref.invalidate(ordersProvider(demoShopId)),
    builder: (orders) {
      final matches = orders.where((o) => o.id == id);
      if (matches.isEmpty) return const Text('注文が見つかりません');
      final order = matches.first;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading('注文 $id', 'サンプル注文'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('注文日時：${orderDate(order.date)}'),
                  const SizedBox(height: 12),
                  Chip(label: Text(order.status)),
                  const Divider(height: 32),
                  for (final l in order.lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.name),
                      subtitle: Text(
                        '数量 ${l.quantity}  ·  単価 ${yen(l.unitPrice)}',
                      ),
                      trailing: Text(yen(l.total)),
                    ),
                  const Divider(height: 32),
                  Text(
                    '合計 ${yen(order.total)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/admin/orders'),
            child: const Text('注文一覧に戻る'),
          ),
        ],
      );
    },
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(shopProvider(demoShopId)),
    retry: () => ref.invalidate(shopProvider(demoShopId)),
    builder: (shop) => ShopForm(shop: shop),
  );
}

class ShopForm extends ConsumerStatefulWidget {
  const ShopForm({super.key, required this.shop});
  final Shop shop;
  @override
  ConsumerState<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends ConsumerState<ShopForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, description, slug;
  late bool published;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.shop.name);
    description = TextEditingController(text: widget.shop.description);
    slug = TextEditingController(text: widget.shop.slug);
    published = widget.shop.published;
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    slug.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const PageHeading('ショップ設定', 'あなたらしいショップをつくりましょう。'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'ショップ名'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'ショップ名を入力してください' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: const InputDecoration(labelText: 'ショップ説明'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: slug,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'ショップURL用ID',
                    helperText: '半角英小文字・数字・ハイフン（例：my-shop）',
                  ),
                  validator: (v) =>
                      !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v ?? '')
                      ? 'URL用IDの形式を確認してください'
                      : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ショップを公開する'),
                  subtitle: const Text('非公開にすると購入者向けページは閲覧できません'),
                  value: published,
                  onChanged: saving
                      ? null
                      : (v) => setState(() => published = v),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? '保存中…' : '設定を保存'),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () => context.go('/shop/${widget.shop.slug}'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('保存済みページをプレビュー'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final repo = ref.read(repositoryProvider);
      if (!await repo.isSlugAvailable(slug.text, widget.shop.id)) {
        if (mounted) showMessage(context, 'このURL用IDは使用されています');
        return;
      }
      await repo.saveShop(
        Shop(
          id: widget.shop.id,
          name: name.text.trim(),
          description: description.text.trim(),
          slug: slug.text,
          published: published,
        ),
      );
      ref.invalidate(shopProvider(demoShopId));
      if (mounted) showMessage(context, 'ショップ設定を保存しました');
    } catch (_) {
      if (mounted) showMessage(context, '設定を保存できませんでした');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

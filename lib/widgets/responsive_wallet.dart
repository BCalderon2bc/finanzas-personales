import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Billetera horizontal: una tarjeta y parte de la siguiente en celular.
class ResponsiveWallet extends StatefulWidget {
  const ResponsiveWallet({
    super.key,
    required this.items,
    required this.selectedId,
    required this.title,
    required this.icon,
    required this.labelFor,
    required this.itemBuilder,
    this.onSelected,
    this.desktopItemWidth = 320,
  });
  final List<Map<String, dynamic>> items;
  final String? selectedId;
  final String title;
  final IconData icon;
  final String Function(Map<String, dynamic>) labelFor;
  final Widget Function(Map<String, dynamic>, bool) itemBuilder;
  final ValueChanged<String>? onSelected;
  final double desktopItemWidth;

  @override
  State<ResponsiveWallet> createState() => _ResponsiveWalletState();
}

class _ResponsiveWalletState extends State<ResponsiveWallet> {
  final controller = ScrollController();
  final measurements = <String, double>{};
  int visibleIndex = 0;
  double itemExtent = 1;

  @override
  void initState() {
    super.initState();
    controller.addListener(trackVisible);
  }

  void trackVisible() {
    if (!mounted || !controller.hasClients || widget.items.isEmpty) {
      return;
    }
    final index = (controller.offset / itemExtent)
        .round()
        .clamp(0, widget.items.length - 1)
        .toInt();
    if (index != visibleIndex) {
      setState(() => visibleIndex = index);
    }
  }

  @override
  void dispose() {
    controller.removeListener(trackVisible);
    controller.dispose();
    super.dispose();
  }

  void move(int direction, double itemWidth) {
    if (!controller.hasClients) {
      return;
    }
    final target = (controller.offset + direction * (itemWidth + 14))
        .clamp(0.0, controller.position.maxScrollExtent)
        .toDouble();
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, box) {
        final mobile = box.maxWidth < 650;
        final itemWidth = mobile && widget.items.length > 1
            ? (box.maxWidth * 0.87).clamp(0.0, 360.0).toDouble()
            : mobile
            ? box.maxWidth
            : widget.desktopItemWidth;
        itemExtent = itemWidth + 14;
        final index = visibleIndex.clamp(0, widget.items.length - 1).toInt();
        final activeId = '${widget.items[index]['id']}';
        final strip = SingleChildScrollView(
          controller: controller,
          primary: false,
          physics: const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.items
                .asMap()
                .entries
                .map(
                  (entry) => Padding(
                padding: EdgeInsets.only(
                  right: entry.key == widget.items.length - 1 ? 0 : 14,
                ),
                child: SizedBox(
                  width: itemWidth,
                  child: _WalletItemExtent(
                    key: ValueKey('measure-${entry.value['id']}'),
                    id: '${entry.value['id']}',
                    measurements: measurements,
                    child: widget.itemBuilder(
                      entry.value,
                      '${entry.value['id']}' == widget.selectedId,
                    ),
                  ),
                ),
              ),
            )
                .toList(),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: const Color(0xFF2563EB), size: 23),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.items.length > 1) ...[
                  IconButton(
                    tooltip: 'Anteriores',
                    onPressed: () => move(-1, itemWidth),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Siguientes',
                    onPressed: () => move(1, itemWidth),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Desliza para ver más. Toca una tarjeta para ver sus detalles.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 14),
            ClipRect(
              child: _WalletViewport(
                activeId: mobile ? activeId : null,
                measurements: measurements,
                bottomPadding: 12,
                child: strip,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Records natural card height in the same layout pass as the viewport.
/// No post-frame callback, setState, or size animation moves the outer list.
class _WalletItemExtent extends SingleChildRenderObjectWidget {
  const _WalletItemExtent({
    super.key,
    required this.id,
    required this.measurements,
    required super.child,
  });
  final String id;
  final Map<String, double> measurements;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWalletItemExtent(id, measurements);
  @override
  void updateRenderObject(
      BuildContext context,
      _RenderWalletItemExtent renderObject,
      ) {
    renderObject.configure(id, measurements);
  }
}

class _RenderWalletItemExtent extends RenderProxyBox {
  _RenderWalletItemExtent(this.id, this.measurements);
  String id;
  Map<String, double> measurements;
  void configure(String value, Map<String, double> sizes) {
    if (id == value && identical(measurements, sizes)) return;
    id = value;
    measurements = sizes;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    measurements[id] = size.height;
  }
}

/// Keeps the horizontal Scrollable at one stable position in the widget tree.
/// The row measures its cards naturally; only the visible card determines the
/// outer height. ClipRect prevents taller neighbouring cards painting outside.
class _WalletViewport extends SingleChildRenderObjectWidget {
  const _WalletViewport({
    required this.activeId,
    required this.measurements,
    required this.bottomPadding,
    required super.child,
  });
  final String? activeId;
  final Map<String, double> measurements;
  final double bottomPadding;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWalletViewport(activeId, measurements, bottomPadding);
  @override
  void updateRenderObject(
      BuildContext context,
      _RenderWalletViewport renderObject,
      ) {
    renderObject.configure(activeId, measurements, bottomPadding);
  }
}

class _RenderWalletViewport extends RenderProxyBox {
  _RenderWalletViewport(this.activeId, this.measurements, this.bottomPadding);
  String? activeId;
  Map<String, double> measurements;
  double bottomPadding;
  void configure(String? id, Map<String, double> sizes, double padding) {
    if (activeId == id &&
        identical(measurements, sizes) &&
        bottomPadding == padding)
      return;
    activeId = id;
    measurements = sizes;
    bottomPadding = padding;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final content = child;
    if (content == null) {
      size = constraints.smallest;
      return;
    }
    content.layout(
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity),
      parentUsesSize: true,
    );
    final measured = activeId == null ? null : measurements[activeId];
    size = constraints.constrain(
      Size(
        content.size.width,
        measured == null ? content.size.height : measured + bottomPadding,
      ),
    );
  }
}

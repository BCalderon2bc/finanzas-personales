import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Billetera horizontal: una tarjeta y parte de la siguiente en celular.
class ResponsiveWallet extends StatefulWidget {
  const ResponsiveWallet({super.key, required this.items,
    required this.selectedId, required this.title, required this.icon,
    required this.labelFor, required this.itemBuilder,
    this.onSelected, this.desktopItemWidth = 320});
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
  final heights = <String, double>{};
  int visibleIndex = 0;
  double itemExtent = 1;

  @override
  void initState() {
    super.initState();
    controller.addListener(trackVisible);
  }

  void trackVisible() {
    if (!mounted || !controller.hasClients || widget.items.isEmpty) { return; }
    final index = (controller.offset / itemExtent).round()
      .clamp(0, widget.items.length - 1).toInt();
    if (index != visibleIndex) { setState(() => visibleIndex = index); }
  }

  void recordHeight(String id, double value) {
    if (!mounted || value <= 0 || (heights[id] != null && (heights[id]! - value).abs() < 0.5)) {
      return;
    }
    heights[id] = value;
    if (widget.items.isNotEmpty &&
        '${widget.items[visibleIndex.clamp(0, widget.items.length - 1).toInt()]['id']}' == id) {
      setState(() {});
    }
  }


  @override
  void dispose() {
    controller.removeListener(trackVisible);
    controller.dispose();
    super.dispose();
  }

  void move(int direction, double itemWidth) {
    if (!controller.hasClients) { return; }
    final target = (controller.offset + direction * (itemWidth + 14))
        .clamp(0.0, controller.position.maxScrollExtent).toDouble();
    controller.animateTo(target, duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) { return const SizedBox.shrink(); }
    return LayoutBuilder(builder: (context, box) {
      final mobile = box.maxWidth < 650;
      final itemWidth = mobile && widget.items.length > 1
          ? (box.maxWidth * 0.87).clamp(0.0, 360.0).toDouble()
          : mobile ? box.maxWidth : widget.desktopItemWidth;
      itemExtent = itemWidth + 14;
      final index = visibleIndex.clamp(0, widget.items.length - 1).toInt();
      final height = heights['${widget.items[index]['id']}'];
      final strip = SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.items.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(right: entry.key == widget.items.length - 1 ? 0 : 14),
              child: SizedBox(width: itemWidth,
                child: _SizeObserver(
                  key: ValueKey('measure-${entry.value['id']}'),
                  onChange: (size) => recordHeight('${entry.value['id']}', size.height),
                  child: widget.itemBuilder(entry.value,
                    '${entry.value['id']}' == widget.selectedId))),
            )).toList()),
        );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(widget.icon, color: const Color(0xFF2563EB), size: 23),
          const SizedBox(width: 9),
          Expanded(child: Text(widget.title, style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700))),
          if (widget.items.length > 1) ...[
            IconButton(tooltip: 'Anteriores', onPressed: () => move(-1, itemWidth),
              icon: const Icon(Icons.chevron_left_rounded)),
            IconButton(tooltip: 'Siguientes', onPressed: () => move(1, itemWidth),
              icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ]),
        const SizedBox(height: 6),
        const Text('Desliza para ver más. Toca una tarjeta para ver sus detalles.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 14),
        if (!mobile || height == null) strip
        else ClipRect(child: AnimatedSize(
          duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero : const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: SizedBox(key: const ValueKey('wallet-viewport'), height: height + 12,
            child: OverflowBox(alignment: Alignment.topLeft,
              minHeight: 0, maxHeight: double.infinity,
              child: strip)),
        )),
      ]);
    });
  }
}

/// Mide el contenido real sin imponer una altura igual a todas las tarjetas.
class _SizeObserver extends SingleChildRenderObjectWidget {
  const _SizeObserver({super.key, required this.onChange, required super.child});
  final ValueChanged<Size> onChange;
  @override
  RenderObject createRenderObject(BuildContext context) => _SizeObserverRender(onChange);
  @override
  void updateRenderObject(BuildContext context, covariant _SizeObserverRender renderObject) {
    renderObject.onChange = onChange;
  }
}

class _SizeObserverRender extends RenderProxyBox {
  _SizeObserverRender(this.onChange);
  ValueChanged<Size> onChange;
  Size? previous;
  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (previous == measured) { return; }
    previous = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) { onChange(measured); }
    });
  }
}

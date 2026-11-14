import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Billetera horizontal con una tarjeta completa por página en celular.
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
    this.revealSelectionOnDesktop = false,
  });
  final List<Map<String, dynamic>> items;
  final String? selectedId;
  final String title;
  final IconData icon;
  final String Function(Map<String, dynamic>) labelFor;
  final Widget Function(Map<String, dynamic>, bool) itemBuilder;
  final ValueChanged<String>? onSelected;
  final double desktopItemWidth;
  final bool revealSelectionOnDesktop;

  @override
  State<ResponsiveWallet> createState() => _ResponsiveWalletState();
}

class _ResponsiveWalletState extends State<ResponsiveWallet> {
  late final controller = ScrollController(
    keepScrollOffset: !widget.revealSelectionOnDesktop,
  );
  final measurements = <String, double>{};
  int visibleIndex = 0;
  double? mobilePageWidth;
  int? lastSelectedIndex;
  bool aligning = false;
  bool canScrollLeft = false;
  bool canScrollRight = false;
  bool checkingScrollEdges = false;
  (String?, int, double, int)? desktopSelection;
  VoidCallback? pendingDesktopReveal;

  @override
  void initState() {
    super.initState();
    controller.addListener(trackVisible);
    controller.addListener(updateScrollEdges);
  }

  void trackVisible() {
    final width = mobilePageWidth;
    if (!mounted ||
        width == null ||
        !controller.hasClients ||
        widget.items.isEmpty) {
      return;
    }
    final index = (controller.offset / width)
        .round()
        .clamp(0, widget.items.length - 1)
        .toInt();
    if (index != visibleIndex) {
      setState(() => visibleIndex = index);
    }
  }

  void alignMobilePage(double width, int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !controller.hasClients ||
          mobilePageWidth != width ||
          lastSelectedIndex != index)
        return;
      final target = (index * width)
          .clamp(0.0, controller.position.maxScrollExtent)
          .toDouble();
      if ((controller.offset - target).abs() < 0.5) return;
      aligning = true;
      try {
        controller.jumpTo(target);
      } finally {
        aligning = false;
      }
    });
  }

  void revealDesktopSelection(double extent, double width, int index) {
    final selection = (widget.selectedId, index, extent, widget.items.length);
    if (desktopSelection == selection) return;
    desktopSelection = selection;
    pendingDesktopReveal = null;
    if (index < 0) return;
    pendingDesktopReveal = () {
      if (!mounted ||
          desktopSelection != selection ||
          widget.selectedId != selection.$1 ||
          !controller.hasClients) {
        return;
      }
      final position = controller.position;
      if (!position.hasContentDimensions || !position.hasViewportDimension) {
        return;
      }
      pendingDesktopReveal = null;
      final left = index * extent;
      final right = left + width;
      final viewportLeft = position.pixels;
      final viewportRight = viewportLeft + position.viewportDimension;
      final target =
          (left < viewportLeft - 0.5
                  ? left
                  : right > viewportRight + 0.5
                  ? right - position.viewportDimension
                  : viewportLeft)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();
      if ((target - viewportLeft).abs() > 0.5) controller.jumpTo(target);
    };
    scheduleDesktopReveal();
  }

  void scheduleDesktopReveal() {
    if (pendingDesktopReveal == null) return;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) pendingDesktopReveal?.call();
    });
  }

  bool selectSettledPage(ScrollEndNotification notification) {
    if (notification.depth != 0 ||
        aligning ||
        mobilePageWidth == null ||
        widget.onSelected == null ||
        widget.items.isEmpty)
      return false;
    final previousSelection = widget.selectedId;
    final index = (notification.metrics.pixels / mobilePageWidth!)
        .round()
        .clamp(0, widget.items.length - 1)
        .toInt();
    final id = '${widget.items[index]['id']}';
    if (id != widget.selectedId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            mobilePageWidth == null ||
            widget.selectedId != previousSelection ||
            ModalRoute.of(context)?.isCurrent == false ||
            visibleIndex >= widget.items.length ||
            '${widget.items[visibleIndex]['id']}' != id)
          return;
        widget.onSelected?.call(id);
      });
    }
    return false;
  }

  @override
  void dispose() {
    controller.removeListener(trackVisible);
    controller.removeListener(updateScrollEdges);
    controller.dispose();
    super.dispose();
  }

  void updateScrollEdges() {
    if (checkingScrollEdges || mobilePageWidth != null) return;
    checkingScrollEdges = true;
    WidgetsBinding.instance.ensureVisualUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkingScrollEdges = false;
      if (!mounted || !controller.hasClients || mobilePageWidth != null) {
        return;
      }
      final position = controller.position;
      if (!position.hasContentDimensions) return;
      final left = position.extentBefore > 0.5;
      final right = position.extentAfter > 0.5;
      if (left == canScrollLeft && right == canScrollRight) return;
      setState(() {
        canScrollLeft = left;
        canScrollRight = right;
      });
    });
  }

  Widget edgeArrow(BuildContext context, int direction, double itemExtent) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withAlpha(218),
      elevation: 2,
      shadowColor: colors.shadow.withAlpha(40),
      shape: CircleBorder(side: BorderSide(color: colors.outlineVariant)),
      child: IconButton(
        tooltip: direction < 0 ? 'Anteriores' : 'Siguientes',
        onPressed: () => move(direction, itemExtent),
        color: colors.primary,
        icon: Icon(
          direction < 0
              ? Icons.chevron_left_rounded
              : Icons.chevron_right_rounded,
        ),
      ),
    );
  }

  void move(int direction, double itemExtent) {
    if (!controller.hasClients) {
      return;
    }
    final start = mobilePageWidth == null
        ? controller.offset
        : (controller.offset / itemExtent).round() * itemExtent;
    final target = (start + direction * itemExtent)
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
    final routeIsCurrent =
        !widget.revealSelectionOnDesktop ||
        (ModalRoute.isCurrentOf(context) ?? true);
    if (widget.items.isEmpty || !routeIsCurrent) {
      desktopSelection = null;
      pendingDesktopReveal = null;
    }
    if (widget.items.isEmpty) {
      mobilePageWidth = null;
      lastSelectedIndex = null;
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, box) {
        final mobile = box.maxWidth < 650;
        // Fit complete cards across the available desktop width.
        final desktopColumns =
            ((box.maxWidth + 14) / (widget.desktopItemWidth + 14))
                .round()
                .clamp(2, 5)
                .toInt();
        final desktopWidth =
            (box.maxWidth - 14 * (desktopColumns - 1)) / desktopColumns;
        final itemWidth = mobile ? box.maxWidth : desktopWidth;
        final itemExtent = mobile ? itemWidth : itemWidth + 14;
        final selectedIndex = widget.items.indexWhere(
          (item) => '${item['id']}' == widget.selectedId,
        );
        if (mobile && itemWidth > 0) {
          desktopSelection = null;
          pendingDesktopReveal = null;
          final targetIndex = selectedIndex < 0 ? 0 : selectedIndex;
          if (mobilePageWidth != itemWidth ||
              lastSelectedIndex != targetIndex) {
            mobilePageWidth = itemWidth;
            lastSelectedIndex = targetIndex;
            visibleIndex = targetIndex;
            alignMobilePage(itemWidth, targetIndex);
          }
        } else {
          mobilePageWidth = null;
          lastSelectedIndex = null;
          if (widget.revealSelectionOnDesktop && routeIsCurrent) {
            revealDesktopSelection(itemExtent, itemWidth, selectedIndex);
          }
        }
        final showDesktopArrows =
            !mobile && widget.items.length > desktopColumns;
        if (showDesktopArrows) updateScrollEdges();
        final index = visibleIndex.clamp(0, widget.items.length - 1).toInt();
        final activeId = '${widget.items[index]['id']}';
        final cards = Row(
          crossAxisAlignment: mobile
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.stretch,
          children: widget.items
              .asMap()
              .entries
              .map(
                (entry) => Padding(
                  padding: EdgeInsets.only(
                    right: mobile || entry.key == widget.items.length - 1
                        ? 0
                        : 14,
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
        );
        final strip = SingleChildScrollView(
          controller: controller,
          primary: false,
          physics: mobile
              ? const PageScrollPhysics(parent: ClampingScrollPhysics())
              : const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: mobile ? cards : IntrinsicHeight(child: cards),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: const Color(0xFF3C70AA), size: 23),
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
                if (mobile && widget.items.length > 1) ...[
                  IconButton(
                    tooltip: 'Anteriores',
                    onPressed: index == 0 ? null : () => move(-1, itemExtent),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Siguientes',
                    onPressed: index == widget.items.length - 1
                        ? null
                        : () => move(1, itemExtent),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              mobile && widget.items.length > 1
                  ? '${index + 1} de ${widget.items.length} · Desliza o usa las flechas'
                  : 'Selecciona una tarjeta para ver sus detalles.',
              style: const TextStyle(color: Color(0xFF596B7D), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Stack(
              children: [
                ClipRect(
                  child: _WalletViewport(
                    activeId: mobile ? activeId : null,
                    measurements: measurements,
                    bottomPadding: 12,
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        if (notification.depth == 0) {
                          updateScrollEdges();
                          scheduleDesktopReveal();
                        }
                        return false;
                      },
                      child: NotificationListener<ScrollEndNotification>(
                        onNotification: selectSettledPage,
                        child: strip,
                      ),
                    ),
                  ),
                ),
                if (showDesktopArrows && canScrollLeft)
                  Positioned(
                    top: 0,
                    bottom: 12,
                    left: 4,
                    child: Center(child: edgeArrow(context, -1, itemExtent)),
                  ),
                if (showDesktopArrows && canScrollRight)
                  Positioned(
                    top: 0,
                    bottom: 12,
                    right: 4,
                    child: Center(child: edgeArrow(context, 1, itemExtent)),
                  ),
              ],
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

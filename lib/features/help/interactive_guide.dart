import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';
import 'guide_catalog.dart';
import 'guide_progress.dart';
export 'guide_catalog.dart';
export 'guide_progress.dart';

String guideUserId() {
  try {
    return supabase.auth.currentUser?.id ?? 'guest';
  } catch (_) {
    return 'guest';
  }
}

/// Permite abrir una pantalla desde el manual y comenzar cuando haya cargado.
class GuideLaunch extends InheritedWidget {
  const GuideLaunch({super.key, required this.topic, required super.child});
  final String topic;
  @override
  bool updateShouldNotify(GuideLaunch oldWidget) => topic != oldWidget.topic;
}

class GuideScope extends StatefulWidget {
  const GuideScope({
    super.key,
    required this.topic,
    required this.child,
    this.ready = true,
    this.welcome = false,
    this.scrollController,
    this.excludedTargets = const {},
    this.userId,
  });
  final String topic;
  final Widget child;
  final bool ready, welcome;
  final ScrollController? scrollController;
  final Set<String> excludedTargets;
  final String? userId;
  static GuideScopeState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GuideHost>()?.state;
  @override
  State<GuideScope> createState() => GuideScopeState();
}

class GuideScopeState extends State<GuideScope> {
  final _ownScroll = ScrollController();
  final Map<String, GlobalKey> _targets = {};
  bool _running = false, _offered = false, _launched = false;
  VoidCallback? _dismiss;
  bool get available => widget.ready && guideCatalog.containsKey(widget.topic);
  String get topic => widget.topic;
  String get userId => widget.userId ?? guideUserId();
  ScrollController get scroll => widget.scrollController ?? _ownScroll;
  List<GuideStep> get steps => (guideCatalog[topic] ?? const <GuideStep>[])
      .where((s) => !widget.excludedTargets.contains(s.target))
      .toList();

  void register(String id, GlobalKey key) => _targets[id] = key;
  void unregister(String id, GlobalKey key) {
    if (_targets[id] == key) _targets.remove(id);
  }

  BuildContext? targetContext(String id) => _targets[id]?.currentContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(GuideScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !available || ModalRoute.of(context)?.isCurrent != true)
        return;
      final launch = context.getInheritedWidgetOfExactType<GuideLaunch>();
      if (!_launched && launch?.topic == topic) {
        _launched = true;
        await start(restart: true);
      } else if (widget.welcome && !_offered && !_running) {
        _offered = true;
        await _welcome();
      }
    });
  }

  Future<void> _welcome() async {
    final uid = userId, progress = GuideProgress(userId);
    if (await progress.welcomeSeen ||
        !mounted ||
        uid != userId ||
        ModalRoute.of(context)?.isCurrent != true ||
        _running)
      return;
    await progress.markWelcome();
    if (!mounted || uid != userId || ModalRoute.of(context)?.isCurrent != true)
      return;
    final begin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bienvenido a Mi Billete'),
        content: const Text(
          'Conoce tu app paso a paso. Resaltaremos los controles y explicaremos cada acción. Puedes omitir la guía y volver desde el botón ?.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Iniciar guía'),
          ),
        ],
      ),
    );
    if (begin == true && mounted && uid == userId) await start(restart: true);
  }

  Future<void> start({bool restart = false}) async {
    if (_running || !mounted) return;
    if (!available) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Espera a que termine de cargar la pantalla.'),
        ),
      );
      return;
    }
    _running = true;
    final uid = userId, route = ModalRoute.of(context);
    final progress = GuideProgress(uid), catalog = steps;
    try {
      var index = 0;
      if (!restart && !await progress.completed(topic)) {
        final target = await progress.resumeAt(topic);
        final found = catalog.indexWhere((s) => s.target == target);
        if (found > 0) index = found;
      }
      if (restart) await progress.restart(topic);
      if (!mounted ||
          uid != userId ||
          route?.isCurrent != true ||
          catalog.isEmpty)
        return;
      FocusManager.instance.primaryFocus?.unfocus();
      final finished = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Guía interactiva',
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, __, ___) => _GuideOverlay(
          owner: this,
          steps: catalog,
          initialIndex: index,
          progress: progress,
          userId: uid,
        ),
      );
      if (finished == true) await progress.complete(topic);
    } finally {
      _running = false;
      _dismiss = null;
    }
  }

  @override
  void dispose() {
    final dismiss = _dismiss;
    if (dismiss != null)
      WidgetsBinding.instance.addPostFrameCallback((_) => dismiss());
    _ownScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GuideHost(
    state: this,
    child: PrimaryScrollController(
      controller: scroll,
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: widget.child,
    ),
  );
}

class _GuideHost extends InheritedWidget {
  const _GuideHost({required this.state, required super.child});
  final GuideScopeState state;
  @override
  bool updateShouldNotify(_GuideHost oldWidget) => true;
}

/// No usa PageStorage: nunca mezcla el estado bool de una pestaña con offsets.
class GuideAnchor extends StatefulWidget {
  const GuideAnchor({super.key, required this.id, required this.child});
  final String id;
  final Widget child;
  @override
  State<GuideAnchor> createState() => _GuideAnchorState();
}

class _GuideAnchorState extends State<GuideAnchor> {
  final _key = GlobalKey();
  GuideScopeState? _owner;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = GuideScope.maybeOf(context);
    if (owner != _owner) {
      _owner?.unregister(widget.id, _key);
      _owner = owner;
    }
    _owner?.register(widget.id, _key);
  }

  @override
  void didUpdateWidget(GuideAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.id != oldWidget.id) _owner?.unregister(oldWidget.id, _key);
    _owner?.register(widget.id, _key);
  }

  @override
  void dispose() {
    _owner?.unregister(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(key: _key, child: widget.child);
}

class _GuideOverlay extends StatefulWidget {
  const _GuideOverlay({
    required this.owner,
    required this.steps,
    required this.initialIndex,
    required this.progress,
    required this.userId,
  });
  final GuideScopeState owner;
  final List<GuideStep> steps;
  final int initialIndex;
  final GuideProgress progress;
  final String userId;
  @override
  State<_GuideOverlay> createState() => _GuideOverlayState();
}

class _GuideOverlayState extends State<_GuideOverlay>
    with WidgetsBindingObserver {
  late int _index;
  int _request = 0;
  Rect? _rect;
  bool _moving = true;
  bool get _valid =>
      mounted && widget.owner.mounted && widget.owner.userId == widget.userId;
  GuideStep get _step => widget.steps[_index];
  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    widget.owner._dismiss = _close;
    WidgetsBinding.instance.addPostFrameCallback((_) => _seek());
  }

  void _close() {
    if (mounted && ModalRoute.of(context)?.isCurrent == true)
      Navigator.pop(context, false);
  }

  @override
  void didChangeMetrics() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _seek();
  });
  Future<void> _seek() async {
    final request = ++_request;
    if (!_valid) {
      _close();
      return;
    }
    setState(() {
      _moving = true;
      _rect = null;
    });
    await widget.progress.saveStep(widget.owner.topic, _step.target);
    bool valid() => _valid && request == _request;
    var target = widget.owner.targetContext(_step.target);
    final scroll = widget.owner.scroll;
    // Los ListView construyen sus hijos al desplazarse. Búsqueda acotada,
    // con pasos de viewport; no supone que todos los controles estén montados.
    if (target == null && scroll.hasClients && scroll.positions.length == 1) {
      await scroll.animateTo(
        scroll.position.minScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
      for (var attempt = 0; attempt < 18 && valid(); attempt++) {
        await WidgetsBinding.instance.endOfFrame;
        target = widget.owner.targetContext(_step.target);
        if (target != null ||
            scroll.position.pixels >= scroll.position.maxScrollExtent - 1)
          break;
        await scroll.animateTo(
          math.min(
            scroll.position.maxScrollExtent,
            scroll.position.pixels + scroll.position.viewportDimension * .65,
          ),
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOut,
        );
      }
    }
    if (!valid()) return;
    if (target != null && target.mounted) {
      try {
        await Scrollable.ensureVisible(
          target,
          alignment: .18,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
        await WidgetsBinding.instance.endOfFrame;
        if (!valid()) return;
        final box = target.findRenderObject();
        if (box is RenderBox && box.hasSize && !box.size.isEmpty) {
          final offset = box.localToGlobal(Offset.zero);
          if (offset.dx.isFinite && offset.dy.isFinite)
            _rect = offset & box.size;
        }
      } catch (_) {
        /* Un control condicional puede desaparecer al reconstruir. */
      }
    }
    if (valid()) setState(() => _moving = false);
  }

  Future<void> _move(int delta) async {
    if (_moving || !_valid) return;
    final next = _index + delta;
    if (next >= widget.steps.length) {
      Navigator.pop(context, true);
      return;
    }
    if (next < 0) return;
    setState(() => _index = next);
    await _seek();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context), size = media.size;
    final safeTop = media.padding.top + 12,
        safeBottom = media.padding.bottom + 12;
    final usable = math.max(100.0, size.height - safeTop - safeBottom);
    final bounds = Rect.fromLTRB(
      6,
      safeTop,
      size.width - 6,
      size.height - safeBottom,
    );
    final rect = _rect?.inflate(5).intersect(bounds);
    final highlight = rect != null && rect.width > 0 && rect.height > 0
        ? rect
        : null;
    final above = highlight != null && highlight.center.dy > size.height * .5;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              _close();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label:
                        'Guía activa. Las acciones de la pantalla están bloqueadas.',
                    child: CustomPaint(painter: _GuidePainter(highlight)),
                  ),
                ),
                Positioned(
                  left: math.max(12.0, (size.width - 440) / 2),
                  right: math.max(12.0, (size.width - 440) / 2),
                  top: above ? safeTop : null,
                  bottom: above ? null : safeBottom,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: math.min(360, usable * .6),
                    ),
                    child: Card(
                      elevation: 14,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          primary: false,
                          key: ValueKey(_step.target),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.explore_outlined,
                                    color: Color(0xFF005544),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Paso ${_index + 1} de ${widget.steps.length}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Omitir guía',
                                    onPressed: _close,
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              LinearProgressIndicator(
                                value: (_index + 1) / widget.steps.length,
                                color: const Color(0xFF005544),
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      _step.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_step.text),
                                  if (_moving)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (!_moving && highlight == null)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Este control aparece cuando hay datos o al elegir esa opción. Puedes continuar.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  TextButton(
                                    onPressed: _moving || _index == 0
                                        ? null
                                        : () => _move(-1),
                                    child: const Text('Anterior'),
                                  ),
                                  TextButton(
                                    onPressed: _close,
                                    child: const Text('Omitir'),
                                  ),
                                  FilledButton(
                                    onPressed: _moving ? null : () => _move(1),
                                    child: Text(
                                      _index == widget.steps.length - 1
                                          ? 'Finalizar'
                                          : 'Siguiente',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.target);
  final Rect? target;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    if (target != null)
      path.addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(12)),
      );
    canvas.drawPath(path, Paint()..color = const Color(0xB8001714));
    if (target != null)
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(12)),
        Paint()
          ..color = const Color(0xFF64E5B6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
  }

  @override
  bool shouldRepaint(_GuidePainter oldDelegate) => oldDelegate.target != target;
}

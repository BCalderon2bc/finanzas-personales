import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/supabase_client.dart';
import 'note_text_controller.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});
  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final title = TextEditingController();
  final body = NoteTextController();
  final bodyFocus = FocusNode();
  List<Map<String, dynamic>> rows = [];
  bool loading = true, saving = false, editorOpen = false, pinned = false;
  String search = '', baseline = '', owner = '';
  String? selectedId, error;
  bool get dirty => editorOpen && snapshot() != baseline;
  String snapshot() =>
      jsonEncode([title.text, body.text, body.document.toJson(), pinned]);

  @override
  void initState() {
    super.initState();
    owner = supabase.auth.currentUser?.id ?? '';
    title.addListener(changed);
    body.addListener(changed);
    load();
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    bodyFocus.dispose();
    super.dispose();
  }

  void checkSession() {
    if (owner.isEmpty || supabase.auth.currentUser?.id != owner) {
      throw StateError('La sesión cambió. Abre Notas nuevamente.');
    }
  }

  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      checkSession();
      final result = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 200) {
        final page = await supabase
            .from('personal_notes')
            .select()
            .eq('user_id', owner)
            .order('is_pinned', ascending: false)
            .order('updated_at', ascending: false)
            .order('id')
            .range(offset, offset + 199);
        result.addAll(List<Map<String, dynamic>>.from(page));
        if (page.length < 200) break;
      }
      checkSession();
      if (mounted)
        setState(() {
          rows = result;
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  Future<bool> keepChanges() async {
    if (!dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
          'Guarda la nota antes de continuar o descarta los cambios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return false;
    if (choice == 'save') return save();
    return choice == 'discard';
  }

  Future<void> open([Map<String, dynamic>? note]) async {
    if (saving || !await keepChanges() || !mounted) return;
    setState(() {
      selectedId = note?['id']?.toString();
      title.text = '${note?['title'] ?? ''}';
      body.load('${note?['body'] ?? ''}', note?['body_format']);
      pinned = note?['is_pinned'] == true;
      editorOpen = true;
      baseline = snapshot();
    });
  }

  Future<bool> save() async {
    if (saving || !editorOpen) return false;
    if (title.text.length > 200 || body.text.length > 20000) {
      message('Máximo 200 caracteres de título y 20,000 de contenido.');
      return false;
    }
    final noteTitle = title.text.trim().isEmpty
        ? 'Nueva nota'
        : title.text.trim();
    setState(() => saving = true);
    try {
      checkSession();
      final data = {
        'title': noteTitle,
        'body': body.text,
        'body_format': body.document.toJson(),
        'is_pinned': pinned,
      };
      final Map<String, dynamic> saved;
      if (selectedId == null) {
        saved = await supabase
            .from('personal_notes')
            .insert({...data, 'user_id': owner})
            .select()
            .single();
      } else {
        saved = await supabase
            .from('personal_notes')
            .update(data)
            .eq('id', selectedId!)
            .eq('user_id', owner)
            .select()
            .single();
      }
      checkSession();
      if (!mounted) return false;
      setState(() {
        selectedId = '${saved['id']}';
        title.text = noteTitle;
        rows.removeWhere((r) => '${r['id']}' == selectedId);
        rows.add(saved);
        rows.sort((a, b) {
          final pin = (b['is_pinned'] == true ? 1 : 0).compareTo(
            a['is_pinned'] == true ? 1 : 0,
          );
          return pin != 0
              ? pin
              : '${b['updated_at']}'.compareTo('${a['updated_at']}');
        });
        baseline = snapshot();
      });
      message('Nota guardada');
      return true;
    } catch (e) {
      message('No se pudo guardar: $e');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    if (selectedId == null || saving) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text('¿Eliminar “${title.text}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => saving = true);
    try {
      checkSession();
      await supabase
          .from('personal_notes')
          .delete()
          .eq('id', selectedId!)
          .eq('user_id', owner);
      checkSession();
      if (mounted)
        setState(() {
          rows.removeWhere((r) => '${r['id']}' == selectedId);
          editorOpen = false;
          selectedId = null;
          baseline = '';
        });
    } catch (e) {
      message('No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String dateLabel(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget noteList() {
    final q = search.trim().toLowerCase();
    final filtered = rows
        .where((r) => '${r['title']} ${r['body']}'.toLowerCase().contains(q))
        .toList();
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar notas',
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} notas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Nueva nota',
                  onPressed: saving ? null : () => open(),
                  icon: const Icon(Icons.note_add_outlined),
                ),
              ],
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: TextStyle(color: colors.error)),
            ),
          Expanded(
            child: filtered.isEmpty && !loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Crea una nota para empezar.'),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final note = filtered[index];
                      final selected =
                          editorOpen && '${note['id']}' == selectedId;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        selected: selected,
                        selectedTileColor: colors.primaryContainer,
                        title: Text(
                          '${note['title']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${note['body']}'.replaceAll('\n', ' '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dateLabel(note['updated_at']),
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: note['is_pinned'] == true
                            ? const Icon(Icons.push_pin, size: 18)
                            : null,
                        onTap: saving ? null : () => open(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void format(void Function() action) {
    if (saving) return;
    action();
    bodyFocus.requestFocus();
  }

  Widget toolbar() {
    final current = body.currentStyle;
    const palette = <String, int?>{
      'Automático': null,
      'Negro': 0xff202124,
      'Gris': 0xff5f6368,
      'Rojo': 0xffb3261e,
      'Azul': 0xff1565c0,
      'Verde': 0xff23734d,
      'Morado': 0xff7b1fa2,
      'Naranja': 0xffb45f06,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          IconButton(
            tooltip: 'Negrita en el texto seleccionado o al escribir',
            isSelected: current.bold,
            onPressed: saving
                ? null
                : () => format(() {
                    final bold = !body.currentStyle.bold;
                    body.apply((s) => s.copyWith(bold: bold));
                  }),
            icon: const Icon(Icons.format_bold),
          ),
          PopupMenuButton<String>(
            enabled: !saving,
            tooltip: 'Color de texto',
            icon: Icon(
              Icons.format_color_text,
              color: current.color == null ? null : Color(current.color!),
            ),
            onSelected: (key) => format(
              () => body.apply(
                (s) => s.copyWith(
                  color: palette[key],
                  clearColor: palette[key] == null,
                ),
              ),
            ),
            itemBuilder: (_) => [
              for (final e in palette.entries)
                PopupMenuItem(
                  value: e.key,
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: e.value == null
                            ? Theme.of(context).colorScheme.onSurface
                            : Color(e.value!),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(e.key),
                    ],
                  ),
                ),
            ],
          ),
          PopupMenuButton<double>(
            enabled: !saving,
            tooltip: 'Tamaño de texto',
            onSelected: (size) =>
                format(() => body.apply((s) => s.copyWith(size: size))),
            itemBuilder: (_) => [
              for (final size in [14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 32.0])
                PopupMenuItem(
                  value: size,
                  child: Text(
                    '${size.toInt()} pt',
                    style: TextStyle(fontSize: size),
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${current.size.toInt()} pt ▾'),
            ),
          ),
          const Text('Selecciona texto para darle formato'),
        ],
      ),
    );
  }

  Widget editor(bool compact) {
    final colors = Theme.of(context).colorScheme;
    if (!editorOpen)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text('Selecciona una nota o crea una nueva'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: saving ? null : () => open(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva nota'),
            ),
          ],
        ),
      );
    return ColoredBox(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                if (compact)
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (await keepChanges() && mounted)
                              setState(() {
                                editorOpen = false;
                                baseline = '';
                              });
                          },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Notas'),
                  ),
                Text(
                  dirty
                      ? 'Sin guardar'
                      : selectedId == null
                      ? 'Nueva nota'
                      : 'Guardada',
                ),
                IconButton(
                  tooltip: pinned ? 'Desfijar nota' : 'Fijar nota',
                  isSelected: pinned,
                  onPressed: saving
                      ? null
                      : () => setState(() => pinned = !pinned),
                  icon: const Icon(Icons.push_pin_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar nota',
                  onPressed: saving || selectedId == null ? null : remove,
                  icon: const Icon(Icons.delete_outline),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.check),
                  label: Text(saving ? 'Guardando…' : 'Guardar'),
                ),
              ],
            ),
          ),
          toolbar(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 20 : 36,
                vertical: 24,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    readOnly: saving,
                    maxLength: 200,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Título',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: false,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: body,
                    focusNode: bodyFocus,
                    readOnly: saving,
                    minLines: 16,
                    maxLines: null,
                    maxLength: 20000,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: colors.onSurface,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu nota…',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || saving) return;
      if (await keepChanges() && mounted) {
        setState(() {
          editorOpen = false;
          baseline = '';
        });
        await WidgetsBinding.instance.endOfFrame;
        if (context.mounted) Navigator.of(context).pop();
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar notas',
            onPressed: saving || loading
                ? null
                : () async {
                    if (await keepChanges() && mounted) {
                      setState(() {
                        editorOpen = false;
                        baseline = '';
                      });
                      await load();
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Nueva nota',
            onPressed: saving ? null : () => open(),
            icon: const Icon(Icons.edit_note),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 760)
              return editorOpen ? editor(true) : noteList();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: (box.maxWidth * .3).clamp(260.0, 360.0),
                  child: noteList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: editor(false)),
              ],
            );
          },
        ),
      ),
    ),
  );
}

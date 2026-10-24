import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import 'category_form_dialog.dart';
import 'category_tile.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}
class _CategoriesPageState extends State<CategoriesPage> {
  List<Map<String, dynamic>> categories = [];
  bool loading = true, saving = false;
  String? error;
  String filter = 'all';
  @override
  void initState() {
    super.initState();
    loadCategories();
  }
  void message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> loadCategories() async {
    setState(() { loading = true; error = null; });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión nuevamente.');
      final rows = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += 500) {
        final result = await supabase.from('categories')
            .select('id, name, category_type, is_active, icon, color')
            .order('name').order('id').range(offset, offset + 499);
        final page = List<Map<String, dynamic>>.from(result);
        rows.addAll(page);
        if (page.length < 500) break;
      }
      if (!mounted) return;
      setState(() { categories = rows; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }
  Future<void> editCategory([Map<String, dynamic>? category]) async {
    if (saving || loading) return;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CategoryFormDialog(category: category, categories: categories),
    );
    if (data == null || !mounted) return;
    final user = supabase.auth.currentUser;
    if (user == null) { message('Debes iniciar sesión nuevamente.'); return; }
    setState(() => saving = true);
    try {
      if (category == null) {
        await supabase.from('categories').insert({...data, 'user_id': user.id});
      } else {
        await supabase.from('categories').update({
          'name': data['name'],
          'icon': data['icon'],
          'color': data['color'],
        })
            .eq('id', category['id']).eq('user_id', user.id).select('id').single();
      }
      if (!mounted) return;
      message(category == null ? 'Categoría creada.' : 'Categoría actualizada.');
      await loadCategories();
    } on PostgrestException catch (e) {
      if (mounted) message(e.code == '23505' ? 'Ya existe una categoría de ese tipo con ese nombre.' : 'No se pudo guardar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  Future<void> toggleCategory(Map<String, dynamic> category) async {
    if (saving || loading) return;
    final user = supabase.auth.currentUser;
    if (user == null) { message('Debes iniciar sesión nuevamente.'); return; }
    final active = category['is_active'] != true;
    setState(() => saving = true);
    try {
      await supabase.from('categories').update({'is_active': active})
          .eq('id', category['id']).eq('user_id', user.id).select('id').single();
      if (!mounted) return;
      message(active ? 'Categoría activada.' : 'Categoría desactivada. Se conserva en el historial.');
      await loadCategories();
    } on PostgrestException catch (e) {
      if (mounted) message('No se pudo actualizar: ${e.message}');
    } catch (e) {
      if (mounted) message('No se pudo actualizar: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final visible = categories.where((c) => filter == 'all' || c['category_type'] == filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías'), actions: [
        IconButton(tooltip: 'Actualizar', onPressed: loading || saving ? null : loadCategories, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: loading || saving ? null : () => editCategory(),
        icon: const Icon(Icons.add), label: Text(saving ? 'Guardando...' : 'Nueva categoría'),
      ),
      body: loading ? const Center(child: CircularProgressIndicator()) : error != null
          ? Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                const Text('No se pudieron cargar las categorías.'),
                const SizedBox(height: 8), SelectableText(error!),
                TextButton(onPressed: loadCategories, child: const Text('Reintentar')),
              ],
            )))
          : RefreshIndicator(onRefresh: loadCategories, child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                DropdownButtonFormField<String>(
                  initialValue: filter, decoration: const InputDecoration(labelText: 'Mostrar categorías'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Todas')),
                    DropdownMenuItem(value: 'income', child: Text('Ingresos')),
                    DropdownMenuItem(value: 'expense', child: Text('Gastos')),
                  ],
                  onChanged: (value) { if (value != null) setState(() => filter = value); },
                ),
                const SizedBox(height: 12),
                if (visible.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text(
                  'No hay categorías. Crea una como Salario, Alimentación o Transporte.', textAlign: TextAlign.center,
                )),

        for (final type in ['income', 'expense'])
          if (visible.any((c) => c['category_type'] == type)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 16, 2, 12),
              child: Row(children: [
                Icon(type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded,
                    size: 18,
                    color: type == 'income' ? const Color(0xFF047857) : const Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(child: Text(type == 'income' ? 'Ingresos' : 'Gastos',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                Text('${visible.where((c) => c['category_type'] == type).length}',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ]),
            ),
            ...visible.where((c) => c['category_type'] == type).map((category) => CategoryTile(
              category: category,
              onEdit: saving ? null : () => editCategory(category),
              onToggle: saving ? null : () => toggleCategory(category),
            )),
          ],
              ],
            )),
    );
  }
}

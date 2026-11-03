import '../../widgets/adaptive_layout.dart';
import '../help/app_help.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';
import '../../utils/money.dart';
import 'person_account_detail_page.dart';
import 'person_account_form_dialog.dart';

class PersonAccountsPage extends StatefulWidget {
  const PersonAccountsPage({super.key});
  @override
  State<PersonAccountsPage> createState() => _PersonAccountsPageState();
}

class _PersonAccountsPageState extends State<PersonAccountsPage> {
  List<Map<String, dynamic>> accounts = [], entries = [];
  List<Map<String, dynamic>> shares = [];
  String? viewerId;
  bool sharedOnly = false;
  bool loading = true, saving = false, archived = false;
  String? error;
  int requestId = 0;
  final search = TextEditingController();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void message(String s) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> load() async {
    final req = ++requestId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final uid = personUserId();
      final rows = await Future.wait([
        personRows('person_accounts', uid, includeShared: true),
        personRows('person_account_entries', uid, includeShared: true),
        personShares(uid),
      ]);
      checkPersonSession(uid);
      if (!mounted || req != requestId) return;
      rows[0].sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );
      setState(() {
        viewerId = uid;
        shares = rows[2];
        accounts = rows[0];
        entries = rows[1];
        loading = false;
      });
    } catch (e) {
      if (mounted && req == requestId)
        setState(() {
          error = '$e';
          loading = false;
        });
    }
  }

  bool owns(Map<String, dynamic> a) => a['user_id'] == viewerId;

  String accountName(Map<String, dynamic> a) => owns(a)
      ? '${a['name']}'
      : '${shares.where((s) => s['person_account_id'] == a['id']).firstOrNull?['owner_email'] ?? 'Titular de la cuenta'}';

  int balance(Map<String, dynamic> a) =>
      (owns(a) ? 1 : -1) *
      personAccountBalance(
        entries.where((e) => e['person_account_id'] == a['id']),
      );

  Future<void> respond(Map<String, dynamic> share, bool accept) async {
    if (saving || loading || viewerId == null) return;
    setState(() => saving = true);
    try {
      checkPersonSession(viewerId!);
      await supabase.rpc(
        'person_share_respond',
        params: {'p_share': share['id'], 'p_accept': accept},
      );
      if (!mounted) return;
      if (accept) setState(() => sharedOnly = true);
      await load();
    } catch (e) {
      message('No se pudo responder a la invitación: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> create() async {
    if (loading || saving) return;
    setState(() => saving = true);
    try {
      final uid = personUserId();
      final data = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => const PersonAccountFormDialog(),
      );
      if (data == null || !mounted) return;
      checkPersonSession(uid);
      final row = await supabase
          .from('person_accounts')
          .insert({...data, 'user_id': uid})
          .select()
          .single();
      checkPersonSession(uid);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              PersonAccountDetailPage(account: Map<String, dynamic>.from(row)),
        ),
      );
      if (mounted) await load();
    } catch (e) {
      message('No se pudo crear: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = compactLayout(context);
    final gutter = pageGutter(context);
    final label = saving ? 'Guardando...' : 'Agregar persona';
    final VoidCallback? add = loading || saving || error != null
        ? null
        : create;
    final visible = accounts
        .where(
          (a) =>
              (archived || a['is_active'] == true) &&
              owns(a) != sharedOnly &&
              accountName(
                a,
              ).toLowerCase().contains(search.text.trim().toLowerCase()),
        )
        .toList();
    int payable = 0, receivable = 0;
    String? invalid;
    try {
      for (final a in accounts.where(
        (a) => a['is_active'] == true && owns(a) != sharedOnly,
      )) {
        final b = balance(a);
        if (b > 0)
          payable += b;
        else
          receivable -= b;
      }
    } catch (e) {
      invalid = '$e';
    }
    return GuideScope(
      topic: 'people',
      ready: !loading && error == null,
      child: Scaffold(
        appBar: AppBar(
          title: GuideAnchor(
            id: 'title',
            child: const Text('Cuentas con personas'),
          ),
          actions: [
            const AppHelpButton(topic: 'people'),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: loading || saving ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        bottomNavigationBar: compact
            ? GuideAnchor(
                id: 'add',
                child: CompactActionBar(
                  label: label,
                  onPressed: add,
                  icon: Icons.person_add_alt_1,
                ),
              )
            : null,
        floatingActionButton: compact
            ? null
            : GuideAnchor(
                id: 'add',
                child: FloatingActionButton.extended(
                  onPressed: add,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(label),
                ),
              ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null || invalid != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text('No se pudieron cargar las cuentas.'),
                        SelectableText(error ?? invalid!),
                        TextButton(
                          onPressed: load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          16,
                          gutter,
                          compact ? 24 : 110,
                        ),
                        children: [
                          const Text(
                            'Lleva la cuenta con cada persona',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sus compras suman (+), las tuyas restan (−). Todas las cuentas se expresan en córdobas.',
                          ),
                          for (final invite in shares.where(
                            (s) =>
                                s['member_id'] == null &&
                                !accounts.any(
                                  (a) =>
                                      a['id'] == s['person_account_id'] &&
                                      owns(a),
                                ),
                          ))
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Invitación de ${invite['owner_email']}',
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        FilledButton(
                                          onPressed: saving
                                              ? null
                                              : () => respond(invite, true),
                                          child: const Text('Aceptar'),
                                        ),
                                        TextButton(
                                          onPressed: saving
                                              ? null
                                              : () => respond(invite, false),
                                          child: const Text('Rechazar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Compartidas conmigo'),
                            value: sharedOnly,
                            onChanged: (value) =>
                                setState(() => sharedOnly = value),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _summary('Tú debes', payable, Icons.north_east),
                              _summary(
                                'Te deben',
                                receivable,
                                Icons.south_west,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Totales de cuentas activas. No se suman a las deudas bancarias del dashboard.',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          GuideAnchor(
                            id: 'filter',
                            child: TextField(
                              controller: search,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Buscar persona',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Mostrar archivadas'),
                            value: archived,
                            onChanged: (v) => setState(() => archived = v),
                          ),
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                sharedOnly
                                    ? 'No hay cuentas compartidas para mostrar.'
                                    : 'Agrega una persona para empezar a registrar sus compras y las tuyas.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ...visible.map((a) {
                            final b = balance(a);
                            final color = b > 0
                                ? Theme.of(context).colorScheme.error
                                : b < 0
                                ? const Color(0xFF087F5B)
                                : Theme.of(context).colorScheme.primary;
                            return Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: saving
                                    ? null
                                    : () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                PersonAccountDetailPage(
                                                  account: a,
                                                ),
                                          ),
                                        );
                                        if (mounted) await load();
                                      },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        child: Text(
                                          accountName(
                                            a,
                                          ).characters.first.toUpperCase(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              accountName(a),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 17,
                                              ),
                                            ),
                                            if (a['is_active'] != true)
                                              const Text('Archivada'),
                                            Text(
                                              '${personBalanceLabel(b)} · ${formatMoneyCents(b.abs(), 'NIO')}',
                                              style: TextStyle(
                                                color: color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summary(String title, int cents, IconData icon) => Container(
    constraints: const BoxConstraints(minWidth: 200),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(height: 8),
        Text(title),
        Text(
          formatMoneyCents(cents, 'NIO'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
        ),
      ],
    ),
  );
}

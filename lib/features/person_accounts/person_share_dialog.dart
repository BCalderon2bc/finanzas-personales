import '../../widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../data/person_account_repository.dart';

class PersonShareDialog extends StatefulWidget {
  const PersonShareDialog({super.key, required this.accountId});
  final String accountId;

  @override
  State<PersonShareDialog> createState() => _PersonShareDialogState();
}

class _PersonShareDialogState extends State<PersonShareDialog> {
  final email = TextEditingController();
  late final String uid;
  Map<String, dynamic>? share;
  bool add = false, editOwn = false, editAll = false;
  bool busy = true, loaded = false;
  String? error;

  @override
  void initState() {
    super.initState();
    uid = personUserId();
    load();
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final rows = await personShares(uid, accountId: widget.accountId);
      if (!mounted) return;
      setState(() {
        share = rows.firstOrNull;
        email.text = share?['invited_email'] as String? ?? '';
        add = share?['can_add'] == true;
        editOwn = share?['can_edit_own'] == true;
        editAll = share?['can_edit_all'] == true;
        loaded = true;
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save({bool remove = false}) async {
    if (busy || !loaded) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      checkPersonSession(uid);
      await supabase.rpc(
        'person_share_manage',
        params: {
          'p_account': widget.accountId,
          'p_email': email.text.trim(),
          'p_add': add,
          'p_edit_own': editOwn,
          'p_edit_all': editAll,
          'p_share': share?['id'],
          'p_remove': remove,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: EdgeInsets.symmetric(
      horizontal: compactLayout(context) ? 12 : 40,
      vertical: compactLayout(context) ? 12 : 24,
    ),
    contentPadding: EdgeInsets.fromLTRB(
      compactLayout(context) ? 16 : 24,
      12,
      compactLayout(context) ? 16 : 24,
      16,
    ),
    title: const Text('Compartir cuenta'),
    content: SizedBox(
      width: 430,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!loaded && !busy)
              TextButton(
                onPressed: () {
                  setState(() => busy = true);
                  load();
                },
                child: const Text('Reintentar'),
              ),
            if (loaded) ...[
              TextField(
                controller: email,
                enabled: !busy && share == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo en Mi Billete',
                ),
              ),
              if (share != null)
                Text(
                  share!['member_id'] == null
                      ? 'Invitación pendiente'
                      : 'Acceso activo',
                )
              else
                const Text(
                  'La invitación aparecerá en la app de la otra persona.',
                ),
              const Text('Siempre puede ver el saldo y el historial.'),
              CheckboxListTile(
                title: const Text('Agregar movimientos'),
                value: add,
                onChanged: busy
                    ? null
                    : (value) => setState(() => add = value!),
              ),
              CheckboxListTile(
                title: const Text('Editar sus movimientos'),
                value: editOwn,
                onChanged: busy
                    ? null
                    : (value) => setState(() => editOwn = value!),
              ),
              CheckboxListTile(
                title: const Text('Editar cualquier movimiento'),
                value: editAll,
                onChanged: busy
                    ? null
                    : (value) => setState(() => editAll = value!),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cerrar'),
      ),
      if (share != null)
        TextButton(
          onPressed: busy ? null : () => save(remove: true),
          child: const Text('Retirar acceso'),
        ),
      FilledButton(
        onPressed: !loaded || busy ? null : () => save(),
        child: Text(share == null ? 'Invitar' : 'Guardar permisos'),
      ),
    ],
  );
}

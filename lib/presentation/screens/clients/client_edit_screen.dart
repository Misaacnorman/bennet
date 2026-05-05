import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';

class ClientEditScreen extends ConsumerStatefulWidget {
  const ClientEditScreen({super.key, this.clientId});

  final int? clientId;

  @override
  ConsumerState<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends ConsumerState<ClientEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late final TextEditingController _opening;
  bool _hydrated = false;

  bool get _isEdit => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController();
    _name = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _notes = TextEditingController();
    _opening = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _hydrateFrom(Client c) {
    if (_hydrated) return;
    _hydrated = true;
    _code.text = c.clientCode;
    _name.text = c.displayName;
    _email.text = c.primaryEmail ?? '';
    _phone.text = c.primaryPhone ?? '';
    _notes.text = c.notes ?? '';
    _opening.text = (c.openingBalanceMinor / 100).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit) {
      final async = ref.watch(clientProvider(widget.clientId!));
      return async.when(
        loading: () => const BennetScaffold(
          title: 'Edit client',
          contentWidth: ContentWidthMode.form,
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => BennetScaffold(
          title: 'Edit client',
          contentWidth: ContentWidthMode.form,
          body: Center(child: Text('$e')),
        ),
        data: (c) {
          if (c == null) {
            return BennetScaffold(
              title: 'Edit client',
              contentWidth: ContentWidthMode.form,
              body: const Center(child: Text('Client not found')),
            );
          }
          _hydrateFrom(c);
          return BennetScaffold(
            title: 'Edit client',
            contentWidth: ContentWidthMode.form,
            body: _form(context),
          );
        },
      );
    }

    return BennetScaffold(
      title: 'New client',
      contentWidth: ContentWidthMode.form,
      body: _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Client code',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _opening,
            decoration: const InputDecoration(
              labelText: 'Opening balance',
              border: OutlineInputBorder(),
              helperText: 'Currency amount',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              final openingMinor = parseMoneyInput(_opening.text) ?? 0;
              final repo = await ref.clientAccounts;
              try {
                if (_isEdit) {
                  await repo.updateClient(
                    UpdateClientInput(
                      id: widget.clientId!,
                      clientCode: _code.text.trim(),
                      displayName: _name.text.trim(),
                      primaryEmail: _email.text.trim().isEmpty
                          ? null
                          : _email.text.trim(),
                      primaryPhone: _phone.text.trim().isEmpty
                          ? null
                          : _phone.text.trim(),
                      notes:
                          _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                      openingBalanceMinor: openingMinor,
                    ),
                  );
                  if (!context.mounted) return;
                  invalidateClientAccounts(ref, clientId: widget.clientId);
                  context.go('/clients/${widget.clientId}');
                } else {
                  final id = await repo.createClient(
                    CreateClientInput(
                      clientCode: _code.text.trim(),
                      displayName: _name.text.trim(),
                      primaryEmail: _email.text.trim().isEmpty
                          ? null
                          : _email.text.trim(),
                      primaryPhone: _phone.text.trim().isEmpty
                          ? null
                          : _phone.text.trim(),
                      notes:
                          _notes.text.trim().isEmpty ? null : _notes.text.trim(),
                      openingBalanceMinor: openingMinor,
                    ),
                  );
                  if (!context.mounted) return;
                  invalidateClientAccounts(ref);
                  context.go('/clients/$id');
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$e')),
                );
              }
            },
            child: Text(_isEdit ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}

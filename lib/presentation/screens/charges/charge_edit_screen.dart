import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';

class ChargeEditScreen extends ConsumerStatefulWidget {
  const ChargeEditScreen({super.key, required this.clientId});

  final int clientId;

  @override
  ConsumerState<ChargeEditScreen> createState() => _ChargeEditScreenState();
}

class _ChargeEditScreenState extends ConsumerState<ChargeEditScreen> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _issued = DateTime.now();
  DateTime? _due;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickIssued() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _issued,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _issued = d);
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? _issued,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = d);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final minor = parseMoneyInput(_amountCtrl.text);
    if (minor == null || minor <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
      return;
    }
    final repo = await ref.clientAccounts;
    try {
      await repo.createCharge(
        CreateChargeInput(
          clientId: widget.clientId,
          amountMinor: minor,
          issuedAt: _issued,
          dueDate: _due,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      invalidateClientAccounts(ref, clientId: widget.clientId);
      GoRouter.of(context).go('/clients/${widget.clientId}');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BennetScaffold(
      title: 'New charge',
      contentWidth: ContentWidthMode.form,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BennetSurface(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Issue date'),
                  subtitle: Text(_issued.toLocal().toString().split(' ').first),
                  trailing: IconButton(
                    tooltip: 'Pick date',
                    onPressed: _pickIssued,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date'),
                  subtitle: Text(
                    _due == null
                        ? 'None'
                        : _due!.toLocal().toString().split(' ').first,
                  ),
                  trailing: IconButton(
                    tooltip: 'Pick due date',
                    onPressed: _pickDue,
                    icon: const Icon(Icons.event_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Create charge')),
        ],
      ),
    );
  }
}

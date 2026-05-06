import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../domain/client_accounts.dart';
import '../../services/data_export_service.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bennet_surface.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _businessCtrl = TextEditingController();
  final _docFooterCtrl = TextEditingController();
  bool _loading = true;
  PaymentMethod _defaultMethod = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = await ref.read(ledgerRepositoryProvider.future);
      final n = await repo.getSetting('business_name');
      final footer = await repo.getSetting('document_secondary_footer');
      final dm = await repo.getSetting('default_payment_method');
      if (!mounted) return;
      _businessCtrl.text = n ?? '';
      _docFooterCtrl.text = footer ?? '';
      if (dm != null && dm.isNotEmpty) {
        try {
          _defaultMethod = PaymentMethodWire.parse(dm);
        } catch (_) {}
      }
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    _docFooterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BennetScaffold(
        title: 'Settings',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return BennetScaffold(
      title: 'Settings',
      contentWidth: ContentWidthMode.narrow,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: BennetSurface(
                clip: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Business',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _businessCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Business / trader name',
                        helperText: 'Shown on PDF receipts and summaries',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _docFooterCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Document footer (secondary line)',
                        helperText: 'Used on statement and receipt footers when wired',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PaymentMethod>(
                      // ignore: deprecated_member_use
                      value: _defaultMethod,
                      decoration: const InputDecoration(
                        labelText: 'Default payment method',
                      ),
                      items: [
                        for (final m in PaymentMethod.values)
                          DropdownMenuItem(
                            value: m,
                            child: Text(m.displayLabel),
                          ),
                      ],
                      onChanged: (v) => setState(
                        () => _defaultMethod = v ?? PaymentMethod.cash,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton(
                  onPressed: () async {
                    final repo = await ref.read(
                      ledgerRepositoryProvider.future,
                    );
                    await repo.setSetting(
                      'business_name',
                      _businessCtrl.text.trim(),
                    );
                    await repo.setSetting(
                      'document_secondary_footer',
                      _docFooterCtrl.text.trim(),
                    );
                    await repo.setSetting(
                      'default_payment_method',
                      _defaultMethod.name,
                    );
                    ref.invalidate(businessNameProvider);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('Saved')));
                  },
                  child: const Text('Save'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Export CSV',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => BennetCsvExports.shareClients(ref),
                      child: const Text('Clients'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          BennetCsvExports.shareChargesRegister(ref),
                      child: const Text('Charges'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          BennetCsvExports.sharePaymentsRegister(ref),
                      child: const Text('Payments'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          BennetCsvExports.shareStatementsIndex(ref),
                      child: const Text('Statements'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

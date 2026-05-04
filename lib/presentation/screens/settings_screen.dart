import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _businessCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final repo = await ref.read(ledgerRepositoryProvider.future);
      final n = await repo.getSetting('business_name');
      if (!mounted) return;
      _businessCtrl.text = n ?? '';
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _businessCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BennetScaffold(title: 'Settings', body: Center(child: CircularProgressIndicator()));
    }
    return BennetScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _businessCtrl,
            decoration: const InputDecoration(
              labelText: 'Business / trader name',
              helperText: 'Shown on PDF receipts and summaries',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              final repo = await ref.read(ledgerRepositoryProvider.future);
              await repo.setSetting('business_name', _businessCtrl.text.trim());
              ref.invalidate(businessNameProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

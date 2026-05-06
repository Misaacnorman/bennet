import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../domain/client_accounts.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';

/// Pick a client before opening [ChargeEditScreen] from the global Charges register.
class ChargePickClientScreen extends ConsumerStatefulWidget {
  const ChargePickClientScreen({super.key});

  @override
  ConsumerState<ChargePickClientScreen> createState() =>
      _ChargePickClientScreenState();
}

class _ChargePickClientScreenState
    extends ConsumerState<ChargePickClientScreen> {
  int? _clientId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(clientsProvider);

    return BennetScaffold(
      title: 'New charge',
      contentWidth: ContentWidthMode.form,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clients) {
          final selectable =
              clients.where((c) => c.status != ClientStatus.archived).toList()
                ..sort(
                  (a, b) => a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  ),
                );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageHeader(
                title: 'New charge',
                subtitle:
                    'Choose the client this charge belongs to. Archived clients are hidden.',
              ),
              const SizedBox(height: 24),
              if (selectable.isEmpty)
                EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'No active clients',
                  subtitle:
                      'Create a client first, then you can issue charges.',
                  action: FilledButton.icon(
                    onPressed: () => context.go('/clients/new'),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('New client'),
                  ),
                )
              else ...[
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value: _clientId,
                  decoration: const InputDecoration(
                    labelText: 'Client',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in selectable)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          '${c.displayName} (${c.clientCode})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _clientId = v),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _clientId == null
                      ? null
                      : () => context.go('/clients/$_clientId/charge/new'),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Continue'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

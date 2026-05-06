import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../application/client_account_providers.dart';
import '../../../core/money.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';

class StatementHistoryScreen extends ConsumerWidget {
  const StatementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statementsHistoryProvider(null));
    final clientsAsync = ref.watch(clientsProvider);

    return BennetScaffold(
      title: 'Statements',
      contentWidth: ContentWidthMode.standard,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => clientsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('$err')),
          data: (clients) {
            final names = {for (final c in clients) c.id: c.displayName};
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageHeader(
                    title: 'Statements',
                    subtitle: 'Issued client statements',
                  ),
                  const SizedBox(height: 24),
                  EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No statements yet',
                    subtitle:
                        'Build and save a statement from a client to see it here.',
                    action: OutlinedButton.icon(
                      onPressed: () => context.go('/clients'),
                      icon: const Icon(Icons.people_outline),
                      label: const Text('Go to clients'),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: PageHeader(
                      title: 'Statements',
                      subtitle: '${list.length} issued',
                    ),
                  );
                }
                final s = list[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BennetSurface(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      title: Text('Statement #${s.statementNumber}'),
                      subtitle: Text(
                        '${DateFormat.yMMMd().format(s.fromDate)} - '
                        '${DateFormat.yMMMd().format(s.toDate)} - '
                        '${names[s.clientId] ?? 'Client #${s.clientId}'}',
                      ),
                      trailing: Text(formatMoney(s.closingBalanceMinor)),
                      onTap: () => context.go('/statements/${s.id}'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

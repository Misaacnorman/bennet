import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../application/client_account_providers.dart';
import '../../../application/providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../../services/statement_pdf_service.dart';
import '../../layout/responsive_content.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';
import '../../widgets/empty_state.dart';

class StatementDetailScreen extends ConsumerWidget {
  const StatementDetailScreen({super.key, required this.statementId});

  final int statementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stmtAsync = ref.watch(statementDetailProvider(statementId));

    return stmtAsync.when(
      loading: () => const BennetScaffold(
        title: 'Statement',
        contentWidth: ContentWidthMode.standard,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Statement',
        contentWidth: ContentWidthMode.standard,
        body: Center(child: Text('$e')),
      ),
      data: (stmt) {
        if (stmt == null) {
          return const BennetScaffold(
            title: 'Statement',
            contentWidth: ContentWidthMode.standard,
            body: Center(child: Text('Not found')),
          );
        }

        final clientAsync = ref.watch(clientProvider(stmt.clientId));
        return clientAsync.when(
          loading: () => const BennetScaffold(
            title: 'Statement',
            contentWidth: ContentWidthMode.standard,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => BennetScaffold(
            title: 'Statement',
            contentWidth: ContentWidthMode.standard,
            body: Center(child: Text('$e')),
          ),
          data: (liveClient) {
            if (liveClient == null) {
              return const BennetScaffold(
                title: 'Statement',
                contentWidth: ContentWidthMode.standard,
                body: Center(child: Text('Client missing')),
              );
            }

            final hasSnap = stmt.linesJson != null &&
                stmt.linesJson!.trim().isNotEmpty;
            if (hasSnap) {
              final pv = statementPreviewFromSnapshot(stmt, liveClient);
              return _StatementDetailLoaded(statement: stmt, preview: pv);
            }

            final previewFall = ref.watch(
              statementPreviewProvider((
                clientId: stmt.clientId,
                from: stmt.fromDate,
                to: stmt.toDate,
              )),
            );

            return previewFall.when(
              loading: () => const BennetScaffold(
                title: 'Statement',
                contentWidth: ContentWidthMode.standard,
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => BennetScaffold(
                title: 'Statement',
                contentWidth: ContentWidthMode.standard,
                body: Center(child: Text('$e')),
              ),
              data: (pv) =>
                  _StatementDetailLoaded(statement: stmt, preview: pv),
            );
          },
        );
      },
    );
  }
}

class _StatementDetailLoaded extends ConsumerWidget {
  const _StatementDetailLoaded({
    required this.statement,
    required this.preview,
  });

  final ClientStatement statement;
  final StatementPreview preview;

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final bn = await ref.read(businessNameProvider.future);
    final ledger = await ref.read(ledgerRepositoryProvider.future);
    final footer = await ledger.getSetting('document_secondary_footer');
    final merged = statement.businessNameSnap ?? bn;
    final bytes = await buildStatementPdf(
      preview: preview,
      businessName: merged,
      statementNumber: statement.statementNumber,
      issuedAt: statement.issuedAt,
      footerSecondary: footer,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/statement_${preview.client.clientCode}_${preview.fromDateMs}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    if (!context.mounted) return;
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = statement;
    final pv = preview;
    final df = DateFormat.yMMMd();

    return BennetScaffold(
      title: 'Statement #${st.statementNumber}',
      contentWidth: ContentWidthMode.standard,
      actions: [
        IconButton(
          tooltip: 'Share PDF',
          onPressed: () => _share(context, ref),
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BennetSurface(
            clip: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: const Text('Client'),
                  subtitle: Text(pv.client.displayName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/clients/${st.clientId}'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Code'),
                  subtitle: Text(pv.client.clientCode),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Period'),
                  subtitle: Text(
                    '${df.format(st.fromDate)} – ${df.format(st.toDate)}',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Issued'),
                  subtitle: Text(df.format(st.issuedAt)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Opening balance'),
                  trailing: Text(formatMoney(st.openingBalanceMinor)),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Closing balance'),
                  trailing: Text(formatMoney(st.closingBalanceMinor)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Line items',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          if (pv.lines.isEmpty)
            const EmptyState(
              icon: Icons.list_alt_outlined,
              title: 'No rows in snapshot',
              subtitle:
                  'This statement was saved before line snapshots existed.',
            )
          else
            BennetSurface(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pv.lines.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final line = pv.lines[i];
                  return ListTile(
                    title: Text(
                      line.detail != null && line.detail!.trim().isNotEmpty
                          ? '${line.label} · ${line.detail}'
                          : line.label,
                    ),
                    subtitle: Text(df.format(line.occurredAt)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatMoney(line.deltaMinor)),
                        Text(
                          formatMoney(line.runningBalanceMinor),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

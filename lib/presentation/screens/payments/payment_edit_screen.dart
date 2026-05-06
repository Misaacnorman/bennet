import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/client_account_providers.dart';
import '../../../application/providers.dart';
import '../../../core/money.dart';
import '../../../domain/client_accounts.dart';
import '../../../domain/entities.dart';
import '../../layout/responsive_content.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/bennet_surface.dart';

class PaymentEditScreen extends ConsumerStatefulWidget {
  const PaymentEditScreen({super.key, this.clientId});

  final int? clientId;

  @override
  ConsumerState<PaymentEditScreen> createState() => _PaymentEditScreenState();
}

class _PaymentEditScreenState extends ConsumerState<PaymentEditScreen> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  PaymentMethod _method = PaymentMethod.cash;
  int? _clientId;
  int? _accountId;
  int? _categoryId;
  bool _loading = true;

  /// Amount strings keyed by charge id (optional payment allocations).
  final Map<int, String> _allocByChargeId = {};
  int _allocSeed = 0;

  @override
  void initState() {
    super.initState();
    _clientId = widget.clientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final book = await ref.read(defaultBookProvider.future);
    final ledger = await ref.read(ledgerRepositoryProvider.future);
    final results = await Future.wait<Object?>([
      ref.read(accountsProvider(book.id).future),
      ref.read(categoriesProvider.future),
      ledger.getSetting('default_payment_method'),
    ]);
    final accounts = results[0] as List<Account>;
    final categories = results[1] as List<Category>;
    final methodStr = results[2] as String?;
    if (!mounted) return;
    setState(() {
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
      Category? inc;
      for (final c in categories) {
        if (c.name.toLowerCase().contains('income')) {
          inc = c;
          break;
        }
      }
      _categoryId =
          inc?.id ?? (categories.isNotEmpty ? categories.first.id : null);
      if (methodStr != null && methodStr.trim().isNotEmpty) {
        try {
          _method = PaymentMethodWire.parse(methodStr.trim());
        } catch (_) {}
      }
      _loading = false;
    });
    final presetClient = widget.clientId;
    if (presetClient != null) {
      await _applyClientDefaults(presetClient);
    }
  }

  Future<void> _applyClientDefaults(int clientId) async {
    final book = await ref.read(defaultBookProvider.future);
    final results = await Future.wait<Object?>([
      ref.read(clientProvider(clientId).future),
      ref.read(accountsProvider(book.id).future),
      ref.read(categoriesProvider.future),
    ]);
    final client = results[0] as Client?;
    final accounts = results[1] as List<Account>;
    final categories = results[2] as List<Category>;
    if (!mounted || client == null) return;
    setState(() {
      final da = client.defaultAccountId;
      if (da != null) {
        for (final a in accounts) {
          if (a.id == da) {
            _accountId = da;
            break;
          }
        }
      }
      final dc = client.defaultCategoryId;
      if (dc != null) {
        for (final c in categories) {
          if (c.id == dc) {
            _categoryId = dc;
            break;
          }
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  void _fillOldestFirst(
    List<({ClientCharge charge, int openMinor})> openCharges,
  ) {
    final totalMinor = parseMoneyInput(_amountCtrl.text);
    if (totalMinor == null || totalMinor <= 0) return;
    var remaining = totalMinor;
    final next = <int, String>{};
    for (final row in openCharges) {
      if (remaining <= 0) break;
      final take = remaining < row.openMinor ? remaining : row.openMinor;
      next[row.charge.id] = (take / 100).toStringAsFixed(2);
      remaining -= take;
    }
    setState(() {
      _allocByChargeId
        ..clear()
        ..addAll(next);
      _allocSeed++;
    });
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
    if (_clientId == null || _accountId == null || _categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick client, account, and category.')),
      );
      return;
    }

    final repo = await ref.clientAccounts;
    try {
      final openRows = await repo.listChargesWithOpenAmount(_clientId!);
      final openById = {for (final r in openRows) r.charge.id: r.openMinor};

      final allocations = <PaymentAllocationInput>[];
      for (final e in _allocByChargeId.entries) {
        final parsed = parseMoneyInput(e.value);
        if (parsed == null || parsed <= 0) continue;
        final om = openById[e.key];
        if (om == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Allocation references an outdated charge list — reopen screen.',
              ),
            ),
          );
          return;
        }
        if (parsed > om) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Allocation for charge ${e.key} exceeds open '
                '${formatMoney(om)}.',
              ),
            ),
          );
          return;
        }
        allocations.add(
          PaymentAllocationInput(chargeId: e.key, amountMinor: parsed),
        );
      }

      final allocSum = allocations.fold<int>(0, (a, x) => a + x.amountMinor);
      if (allocSum > minor) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Allocated amounts exceed payment total.'),
          ),
        );
        return;
      }

      final paymentId = await repo.recordPayment(
        RecordPaymentInput(
          clientId: _clientId!,
          amountMinor: minor,
          receivedAt: _date,
          method: _method,
          accountId: _accountId!,
          categoryId: _categoryId!,
          allocations: allocations,
          reference: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      invalidateClientAccounts(ref, clientId: _clientId);
      invalidateLedger(ref);
      GoRouter.of(context).go('/payments/$paymentId');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const BennetScaffold(
        title: 'Record payment',
        contentWidth: ContentWidthMode.form,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final clientsAsync = ref.watch(clientsProvider);
    final bookAsync = ref.watch(defaultBookProvider);

    return BennetScaffold(
      title: 'Record payment',
      contentWidth: ContentWidthMode.standard,
      body: bookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (book) {
          final accountsAsync = ref.watch(accountsProvider(book.id));
          final categoriesAsync = ref.watch(categoriesProvider);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BennetSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    clientsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('$e'),
                      data: (clients) {
                        return DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _clientId,
                          decoration: const InputDecoration(
                            labelText: 'Client',
                          ),
                          items: [
                            for (final c in clients)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.displayName),
                              ),
                          ],
                          onChanged: (v) async {
                            setState(() {
                              _clientId = v;
                              _allocByChargeId.clear();
                              _allocSeed++;
                            });
                            if (v != null) {
                              await _applyClientDefaults(v);
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount received',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              if (_clientId != null) ...[
                const SizedBox(height: 16),
                BennetSurface(
                  accent: AppSemanticColors.attention,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Apply to open charges',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optional. Blank remainder stays unallocated on the receipt.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Builder(
                        builder: (context) {
                          final async = ref.watch(
                            chargesWithOpenAmountProvider(_clientId!),
                          );
                          return async.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('$e'),
                            data: (openCharges) {
                              if (openCharges.isEmpty) {
                                return Text(
                                  'No open charges with balance.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () =>
                                            _fillOldestFirst(openCharges),
                                        icon: const Icon(
                                          Icons.auto_fix_high_outlined,
                                        ),
                                        label:
                                            const Text('Fill oldest first'),
                                      ),
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _allocByChargeId.clear();
                                          _allocSeed++;
                                        }),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  ),
                                  for (final row in openCharges)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  row.charge.description ??
                                                      'Charge #${row.charge.id}',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium,
                                                ),
                                                Text(
                                                  'Open '
                                                  '${formatMoney(row.openMinor)} - '
                                                  '${row.charge.issuedAt.toLocal().toString().split(' ').first}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 112,
                                            child: _ChargeAllocationField(
                                              chargeId: row.charge.id,
                                              seed: _allocSeed,
                                              initialText:
                                                  _allocByChargeId[row
                                                      .charge
                                                      .id] ??
                                                  '',
                                              onChanged: (s) =>
                                                  _allocByChargeId[row
                                                          .charge
                                                          .id] =
                                                      s,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              BennetSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Received date'),
                      subtitle: Text(
                        _date.toLocal().toString().split(' ').first,
                      ),
                      trailing: IconButton(
                        tooltip: 'Pick date',
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                      ),
                    ),
                    DropdownButtonFormField<PaymentMethod>(
                      // ignore: deprecated_member_use
                      value: _method,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items: [
                        for (final m in PaymentMethod.values)
                          DropdownMenuItem(
                            value: m,
                            child: Text(m.displayLabel),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _method = v ?? PaymentMethod.cash),
                    ),
                    const SizedBox(height: 12),
                    accountsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (err, _) => const SizedBox.shrink(),
                      data: (accounts) {
                        return DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _accountId,
                          decoration: const InputDecoration(
                            labelText: 'Deposit account',
                          ),
                          items: [
                            for (final a in accounts)
                              DropdownMenuItem(
                                value: a.id,
                                child: Text(a.name),
                              ),
                          ],
                          onChanged: (v) => setState(() => _accountId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    categoriesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (err, _) => const SizedBox.shrink(),
                      data: (categories) {
                        return DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _categoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            for (final c in categories)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              BennetSurface(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _refCtrl,
                      decoration: const InputDecoration(labelText: 'Reference'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Post payment')),
            ],
          );
        },
      ),
    );
  }
}

class _ChargeAllocationField extends StatefulWidget {
  const _ChargeAllocationField({
    required this.chargeId,
    required this.seed,
    required this.initialText,
    required this.onChanged,
  });

  final int chargeId;
  final int seed;
  final String initialText;
  final ValueChanged<String> onChanged;

  @override
  State<_ChargeAllocationField> createState() => _ChargeAllocationFieldState();
}

class _ChargeAllocationFieldState extends State<_ChargeAllocationField> {
  late TextEditingController _controller;

  void _emit() => widget.onChanged(_controller.text);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _controller.addListener(_emit);
  }

  @override
  void didUpdateWidget(covariant _ChargeAllocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seed != oldWidget.seed ||
        widget.chargeId != oldWidget.chargeId) {
      _controller.removeListener(_emit);
      _controller.dispose();
      _controller = TextEditingController(text: widget.initialText);
      _controller.addListener(_emit);
    } else if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_emit);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(hintText: '0', isDense: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
    );
  }
}

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../application/providers.dart';
import '../../core/money.dart';
import '../layout/responsive_content.dart';
import '../widgets/app_scaffold.dart';

class TaxExportScreen extends ConsumerStatefulWidget {
  const TaxExportScreen({super.key});

  @override
  ConsumerState<TaxExportScreen> createState() => _TaxExportScreenState();
}

class _TaxExportScreenState extends ConsumerState<TaxExportScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, 1, 1),
    end: DateTime(DateTime.now().year, 12, 31),
  );

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _exportCsv(int bookId) async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
    ).add(const Duration(days: 1));
    final rollups = await repo.categoryRollups(
      bookId: bookId,
      from: from,
      to: to,
    );

    final rows = <List<String>>[
      ['Category', 'Income', 'Expense', 'Net'],
      ...rollups.map(
        (r) => [
          r.categoryName,
          (r.incomeMinor / 100).toStringAsFixed(2),
          (r.expenseMinor / 100).toStringAsFixed(2),
          (r.netMinor / 100).toStringAsFixed(2),
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bennet_tax_$bookId.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Bennet category summary CSV');
  }

  Future<void> _exportPdf(int bookId) async {
    final repo = await ref.read(ledgerRepositoryProvider.future);
    final from = DateTime(
      _range.start.year,
      _range.start.month,
      _range.start.day,
    );
    final to = DateTime(
      _range.end.year,
      _range.end.month,
      _range.end.day,
    ).add(const Duration(days: 1));
    final rollups = await repo.categoryRollups(
      bookId: bookId,
      from: from,
      to: to,
    );
    final business = await repo.getSetting('business_name');

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.standard,
        build: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(32),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                business?.trim().isNotEmpty == true
                    ? business!.trim()
                    : 'Bennet summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${DateFormat.yMMMd().format(_range.start)} – ${DateFormat.yMMMd().format(_range.end)}',
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    children: ['Category', 'Income', 'Expense', 'Net']
                        .map(
                          (h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                              h,
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ...rollups.map(
                    (r) => pw.TableRow(
                      children:
                          [
                                r.categoryName,
                                formatMoney(r.incomeMinor),
                                formatMoney(r.expenseMinor),
                                formatMoney(r.netMinor),
                              ]
                              .map(
                                (cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(cell),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              pw.Text(
                'For informational use only — consult a tax professional for filings.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ),
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/bennet_summary_$bookId.pdf');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(file.path),
    ], subject: 'Bennet tax summary PDF');
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(defaultBookProvider);

    return bookAsync.when(
      loading: () => const BennetScaffold(
        title: 'Tax export',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => BennetScaffold(
        title: 'Tax export',
        body: Center(child: Text('$e')),
      ),
      data: (book) => BennetScaffold(
        title: 'Tax export',
        contentWidth: ContentWidthMode.narrow,
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date range'),
              subtitle: Text(
                '${DateFormat.yMMMd().format(_range.start)} – ${DateFormat.yMMMd().format(_range.end)}',
              ),
              trailing: const Icon(Icons.date_range),
              onTap: _pickRange,
            ),
            const SizedBox(height: 16),
            Text(
              'Exports category totals for the selected range for your records or accountant. This does not file taxes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () => _exportCsv(book.id),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Export CSV'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _exportPdf(book.id),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Export PDF summary'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

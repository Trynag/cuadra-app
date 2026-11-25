import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';
import '../widgets/quick_entry_sheet.dart';

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  void _showAddJobDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    IncomeFrequency freq = IncomeFrequency.monthly;
    String accountId = 'acc_davibank';

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final accounts = context.read<FinanceController>().accounts;
          return AlertDialog(
            title: const Text('Nuevo trabajo o fuente'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre (ej. UNAD, Freelance)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<IncomeFrequency>(
                  value: freq,
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                  items: [
                    for (final f in IncomeFrequency.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => freq = v ?? freq),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Monto típico (COP)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: accountId,
                  decoration: const InputDecoration(labelText: 'Cuenta destino'),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => accountId = v ?? accountId),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final amt = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  await context.read<FinanceController>().addIncomeSource(
                        name: nameCtrl.text,
                        frequency: freq,
                        defaultAmount: amt,
                        defaultAccountId: accountId,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final summary = ctrl.summary;
    final activeSources = ctrl.incomeSources.where((s) => s.isActive).toList();
    final pausedSources = ctrl.incomeSources.where((s) => !s.isActive).toList();
    final breakdownMap = {for (final b in ctrl.incomeBreakdown) b.sourceId: b};
    final accountMap = {for (final a in ctrl.accounts) a.id: a};

    final incomeTxs = ctrl.transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.transferStatus != TransferStatus.confirmedMirror)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cuadre del mes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Entradas reales'),
                    Text(
                      '+${formatCOP(summary.monthlyIncome)}',
                      style: CuadraTheme.monoAmount.copyWith(color: CuadraTheme.emerald700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gastos reales'),
                    Text('-${formatCOP(summary.realMonthlyExpenses)}', style: CuadraTheme.monoAmount),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cuadre neto'),
                    Text(
                      '${summary.freeCashflow >= 0 ? '+' : ''}${formatCOP(summary.freeCashflow)}',
                      style: CuadraTheme.monoAmount.copyWith(
                        color: summary.freeCashflow >= 0 ? CuadraTheme.emerald700 : CuadraTheme.red700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mis trabajos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    OutlinedButton.icon(
                      onPressed: () => _showAddJobDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
                for (final src in activeSources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(src.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      '${src.frequency.label} · ${accountMap[src.defaultAccountId]?.name ?? ''} · +${formatCOP(breakdownMap[src.id]?.totalReceived ?? 0)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: () => showQuickEntrySheet(
                            context,
                            initialMode: TransactionType.income,
                            initialIncomeSourceId: src.id,
                            initialAccountId: src.defaultAccountId,
                          ),
                          child: Text(src.frequency == IncomeFrequency.daily ? 'Cobrar día' : 'Pago'),
                        ),
                        IconButton(
                          tooltip: 'Pausar trabajo',
                          icon: const Icon(Icons.pause_circle_outline),
                          onPressed: () => ctrl.toggleIncomeSourceActive(src.id),
                        ),
                      ],
                    ),
                  ),
                if (pausedSources.isNotEmpty) ...[
                  const Divider(),
                  const Text(
                    'Trabajos pausados (historial intacto)',
                    style: TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                  ),
                  for (final src in pausedSources)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(src.name),
                      trailing: TextButton(
                        onPressed: () => ctrl.toggleIncomeSourceActive(src.id),
                        child: const Text('Reactivar'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historial de entradas (cuándo y por qué)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final tx in incomeTxs)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx.incomeReason ?? tx.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${accountMap[tx.accountId]?.name ?? 'Cuenta'} · ${DateFormat('EEE dd MMM', 'es_CO').format(DateTime.parse(tx.dateIso))}',
                      style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                    ),
                    trailing: Text(
                      '+${formatCOP(tx.amount)}',
                      style: CuadraTheme.monoAmount.copyWith(color: CuadraTheme.emerald700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';
import '../widgets/quick_entry_sheet.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key, required this.onJumpToTab});

  final ValueChanged<int> onJumpToTab;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final summary = ctrl.summary;
    final activeSources = ctrl.incomeSources.where((s) => s.isActive).toList();
    final breakdownMap = {for (final b in ctrl.incomeBreakdown) b.sourceId: b};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (ctrl.pendingMirrorPairs.isNotEmpty) ...[
          Card(
            color: const Color(0xFFF0FDFA),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF99F6E4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detectamos ${ctrl.pendingMirrorPairs.length} traslado espejo entre tus cuentas',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  for (final pair in ctrl.pendingMirrorPairs)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${pair.fromAccountName} → ${pair.toAccountName} (${formatCOP(pair.amount)})',
                            style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ctrl.reconcileMirrorPair(pair),
                          child: const Text('Enlazar'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Financial Pulse Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Disponible real hoy (cuentas y efectivo)',
                  style: TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                ),
                const SizedBox(height: 4),
                Text(
                  formatCOP(summary.totalLiquid),
                  style: CuadraTheme.monoAmount.copyWith(fontSize: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  'Efectivo: ${formatCOP(summary.cashOnlyTotal)} · Nequi: ${formatCOP(summary.nequiOnlyTotal)} · Bancos: ${formatCOP(summary.banksSavingsTotal)}',
                  style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: CuadraTheme.emerald700,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        onPressed: () => showQuickEntrySheet(
                          context,
                          initialMode: TransactionType.income,
                        ),
                        icon: const Icon(Icons.trending_up, size: 18),
                        label: const Text('Ingreso'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: () => showQuickEntrySheet(
                          context,
                          initialMode: TransactionType.transfer,
                          initialAccountId: 'acc_davibank',
                        ),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                        label: const Text('A Nequi'),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Entradas mes',
                        value: '+${formatCOP(summary.monthlyIncome)}',
                        color: CuadraTheme.emerald700,
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'Gasto real',
                        value: formatCOP(summary.realMonthlyExpenses),
                      ),
                    ),
                    Expanded(
                      child: _MetricTile(
                        label: 'Cuadre neto',
                        value: '${summary.freeCashflow >= 0 ? '+' : ''}${formatCOP(summary.freeCashflow)}',
                        color: summary.freeCashflow >= 0
                            ? CuadraTheme.emerald700
                            : CuadraTheme.red700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Daily Priority: Efectivo & Nequi + Banks
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus cuentas y efectivo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final acc in ctrl.accounts) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF1F5F9),
                      child: Text(
                        acc.institution.shortCode,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '+${formatCOP(summary.accountFlows[acc.id]?.inflow ?? 0)} · -${formatCOP(summary.accountFlows[acc.id]?.outflow ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatCOP(acc.balance), style: CuadraTheme.monoAmount.copyWith(fontSize: 14)),
                        if (acc.institution == AccountInstitution.efectivo ||
                            acc.institution == AccountInstitution.nequi)
                          IconButton(
                            tooltip: 'Registrar gasto rápido',
                            icon: const Icon(Icons.add_circle, color: CuadraTheme.slate900),
                            onPressed: () => showQuickEntrySheet(
                              context,
                              initialMode: TransactionType.expense,
                              initialAccountId: acc.id,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Active Jobs Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tus trabajos del mes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => onJumpToTab(1),
                      child: const Text('Gestionar'),
                    ),
                  ],
                ),
                for (final src in activeSources)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(src.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      '${src.frequency.label} · +${formatCOP(breakdownMap[src.id]?.totalReceived ?? 0)}',
                      style: const TextStyle(fontSize: 12, color: CuadraTheme.emerald700),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => showQuickEntrySheet(
                        context,
                        initialMode: TransactionType.income,
                        initialIncomeSourceId: src.id,
                        initialAccountId: src.defaultAccountId,
                      ),
                      child: Text(src.frequency == IncomeFrequency.daily ? '+ Día' : '+ Pago'),
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: CuadraTheme.slate600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: CuadraTheme.monoAmount.copyWith(fontSize: 14, color: color ?? CuadraTheme.slate900),
        ),
      ],
    );
  }
}

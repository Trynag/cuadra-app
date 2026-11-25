import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';
import '../widgets/quick_entry_sheet.dart';

class DebtsScreen extends StatelessWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final plan = ctrl.debtPlan;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Deuda total consolidada', style: TextStyle(fontSize: 12, color: CuadraTheme.slate600)),
                Text(formatCOP(ctrl.summary.totalDebt), style: CuadraTheme.monoAmount.copyWith(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  'Libre de deudas en ${plan.totalMonths} meses · Ahorro en intereses: ${formatCOP(plan.interestSavedVsMinimum)}',
                  style: const TextStyle(fontSize: 12, color: CuadraTheme.teal700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SegmentedButton<DebtStrategy>(
                  segments: const [
                    ButtonSegment(value: DebtStrategy.avalanche, label: Text('Avalancha')),
                    ButtonSegment(value: DebtStrategy.snowball, label: Text('Bola de nieve')),
                  ],
                  selected: {ctrl.debtStrategy},
                  onSelectionChanged: (set) =>
                      ctrl.updateDebtStrategy(set.first, ctrl.extraDebtBudget),
                ),
                const SizedBox(height: 12),
                Text(
                  'Abono extra mensual: ${formatCOP(ctrl.extraDebtBudget)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Slider(
                  min: 0,
                  max: 1000000,
                  divisions: 20,
                  value: ctrl.extraDebtBudget.clamp(0, 1000000),
                  onChanged: (v) => ctrl.updateDebtStrategy(ctrl.debtStrategy, v),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final debt in ctrl.debts) ...[
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                'Tasa ${debt.aprEa.toStringAsFixed(1)}% EA · Cuota mín. ${formatCOP(debt.minimumPayment)} · Día ${debt.dueDay}',
                style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatCOP(debt.balance), style: CuadraTheme.monoAmount.copyWith(fontSize: 14)),
                  InkWell(
                    onTap: () => showQuickEntrySheet(
                      context,
                      initialMode: TransactionType.debtPayment,
                      initialAccountId: 'acc_davibank',
                      initialDebtId: debt.id,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Abonar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CuadraTheme.teal700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

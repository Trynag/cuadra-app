import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final statuses = ctrl.summary.budgetStatuses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in statuses) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.budget.category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        '${item.percent}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: item.status == 'exceeded'
                              ? CuadraTheme.red700
                              : item.status == 'warning'
                                  ? CuadraTheme.amber700
                                  : CuadraTheme.emerald700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 8,
                      value: (item.percent / 100).clamp(0.0, 1.0),
                      color: item.status == 'exceeded'
                          ? CuadraTheme.red700
                          : item.status == 'warning'
                              ? CuadraTheme.amber700
                              : CuadraTheme.teal700,
                      backgroundColor: const Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gastado: ${formatCOP(item.spent)}', style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600)),
                      Text('Tope: ${formatCOP(item.budget.monthlyLimit)}', style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600)),
                    ],
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

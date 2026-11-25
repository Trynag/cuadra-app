import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final accountMap = {for (final a in ctrl.accounts) a.id: a};

    final items = ctrl.transactions.where((tx) {
      final isTransfer = tx.type == TransactionType.transfer ||
          tx.transferStatus == TransferStatus.confirmedMirror;
      return switch (_filter) {
        'incomes' => tx.type == TransactionType.income && !isTransfer,
        'spontaneous' => isSpontaneousAccount(tx.accountId) && !isTransfer,
        'transfers' => isTransfer || tx.transferStatus == TransferStatus.pendingReview,
        _ => true,
      };
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              for (final entry in const [
                ('all', 'Todos'),
                ('incomes', 'Ingresos'),
                ('spontaneous', 'Efectivo y Nequi'),
                ('transfers', 'Traslados'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.$2),
                    selected: _filter == entry.$1,
                    onSelected: (_) => setState(() => _filter = entry.$1),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tx = items[index];
              final acc = accountMap[tx.accountId];
              final isTransfer = tx.type == TransactionType.transfer ||
                  tx.transferStatus == TransferStatus.confirmedMirror;
              final sign = isTransfer ? '' : (tx.type == TransactionType.income ? '+' : '-');
              final color = isTransfer
                  ? CuadraTheme.slate600
                  : tx.type == TransactionType.income
                      ? CuadraTheme.emerald700
                      : CuadraTheme.slate900;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  '${acc?.name ?? 'Cuenta'} · ${tx.category} · ${DateFormat('dd MMM', 'es_CO').format(DateTime.parse(tx.dateIso))}',
                  style: const TextStyle(fontSize: 12, color: CuadraTheme.slate600),
                ),
                trailing: Text(
                  '$sign${formatCOP(tx.amount)}',
                  style: CuadraTheme.monoAmount.copyWith(color: color, fontSize: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cuadra_mobile/data/seed_data.dart';
import 'package:cuadra_mobile/models/finance_models.dart';
import 'package:cuadra_mobile/services/finance_engine.dart';

void main() {
  test('formatCOP formats Colombian pesos cleanly', () {
    expect(formatCOP(3200000), '\$3.200.000');
    expect(formatCOP(85000), '\$85.000');
  });

  test('detectInternalTransfers identifies Davibank -> Nequi mirror pair', () {
    final accounts = SeedData.accounts('test_user');
    final txs = SeedData.transactions('test_user');
    final pairs = detectInternalTransfers(txs, accounts);
    expect(pairs.length, 1);
    expect(pairs.first.amount, 180000);
    expect(pairs.first.fromAccountName, 'Davibank Ahorros');
    expect(pairs.first.toAccountName, 'Nequi');
  });

  test('calculateIncomeBreakdown separates UNAD and Trabajo diario accurately', () {
    final sources = SeedData.incomeSources('test_user');
    final txs = SeedData.transactions('test_user')
        .where((t) => t.transferStatus != TransferStatus.pendingReview)
        .toList();
    final breakdown = calculateIncomeBreakdown(sources, txs);
    final unad = breakdown.firstWhere((b) => b.sourceId == 'src_unad');
    final diario = breakdown.firstWhere((b) => b.sourceId == 'src_diario');
    expect(unad.totalReceived, 3200000);
    expect(diario.totalReceived, 180000);
  });

  test('simulateDebtPayoff rewards extra monthly budget with fewer months', () {
    final debts = SeedData.debts('test_user');
    final plan = simulateDebtPayoff(
      debts: debts,
      strategy: DebtStrategy.avalanche,
      extraMonthlyBudget: 300000,
    );
    expect(plan.monthsSavedVsMinimum, greaterThan(0));
    expect(plan.interestSavedVsMinimum, greaterThan(0));
  });
}

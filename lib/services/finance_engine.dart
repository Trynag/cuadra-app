import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/finance_models.dart';

const List<String> kExpenseCategories = [
  'Comida fuera',
  'Mercado y Hogar',
  'Transporte',
  'Antojos y Hormiga',
  'Servicios y Fijos',
  'Suscripciones',
  'Salud y Cuidado',
  'Envíos a personas',
  'Pago de deuda',
];

final NumberFormat _copFormatter = NumberFormat('#,##0', 'es_CO');

String formatCOP(num amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  return '$sign\$${_copFormatter.format(rounded.abs())}';
}

String categorizeTransaction(String description, {String? accountId, double? amount}) {
  final text = description.trim().toLowerCase();
  if (text.isEmpty) return 'Antojos y Hormiga';

  const rules = <String, List<String>>{
    'Comida fuera': ['rappi', 'almuerzo', 'corrientazo', 'crepes', 'domicilio', 'restaurante', 'cena'],
    'Mercado y Hogar': ['d1', 'ara', 'exito', 'éxito', 'jumbo', 'carulla', 'mercado', 'fruver', 'olimpo'],
    'Transporte': ['uber', 'didi', 'indrive', 'transmilenio', 'sitp', 'mio', 'metro', 'taxi', 'gasolina', 'parqueadero'],
    'Antojos y Hormiga': ['juan valdez', 'tostao', 'café', 'cafe', 'tinto', 'empanada', 'pandebono', 'panaderia', 'tienda'],
    'Servicios y Fijos': ['arriendo', 'epm', 'enel', 'vanti', 'acueducto', 'claro', 'movistar', 'tigo', 'internet', 'administracion'],
    'Suscripciones': ['netflix', 'spotify', 'youtube', 'disney', 'chatgpt', 'icloud', 'smart fit'],
    'Salud y Cuidado': ['farmatodo', 'cruz verde', 'drogueria', 'eps', 'barberia', 'peluqueria'],
    'Envíos a personas': ['envio a', 'envío a', 'vaca', 'prestamo', 'pago a'],
  };

  for (final entry in rules.entries) {
    if (entry.value.any(text.contains)) {
      return entry.key;
    }
  }

  if ((accountId == 'acc_efectivo' || accountId == 'acc_nequi') &&
      amount != null &&
      amount <= 20000) {
    return 'Antojos y Hormiga';
  }

  return 'Comida fuera';
}

bool isSpontaneousAccount(String accountId) =>
    accountId == 'acc_efectivo' || accountId == 'acc_nequi';

List<MirrorPairCandidate> detectInternalTransfers(
  List<TransactionRecord> transactions,
  List<Account> accounts,
) {
  final accountMap = {for (final a in accounts) a.id: a};
  final candidates = <MirrorPairCandidate>[];
  final usedIds = <String>{};

  final outflows = transactions
      .where((t) =>
          (t.type == TransactionType.expense || t.type == TransactionType.transfer) &&
          t.transferStatus != TransferStatus.confirmedMirror &&
          (t.linkedTransferId == null || t.linkedTransferId!.isEmpty))
      .toList();

  final inflows = transactions
      .where((t) =>
          t.type == TransactionType.income &&
          t.transferStatus != TransferStatus.confirmedMirror &&
          (t.linkedTransferId == null || t.linkedTransferId!.isEmpty))
      .toList();

  for (final outTx in outflows) {
    if (usedIds.contains(outTx.id)) continue;
    final outTime = DateTime.tryParse(outTx.dateIso);
    if (outTime == null) continue;

    TransactionRecord? match;
    for (final inTx in inflows) {
      if (usedIds.contains(inTx.id)) continue;
      if (inTx.accountId == outTx.accountId) continue;
      if ((inTx.amount - outTx.amount).abs() > 1) continue;
      final inTime = DateTime.tryParse(inTx.dateIso);
      if (inTime == null) continue;
      if (inTime.difference(outTime).abs().inHours > 24) continue;

      final combined = '${outTx.description} ${inTx.description}'.toLowerCase();
      final looksInternal = combined.contains('nequi') ||
          combined.contains('davibank') ||
          combined.contains('pse') ||
          combined.contains('recarga') ||
          combined.contains('traslado') ||
          outTx.transferStatus == TransferStatus.pendingReview;
      if (looksInternal) {
        match = inTx;
        break;
      }
    }

    if (match != null) {
      usedIds.add(outTx.id);
      usedIds.add(match.id);
      final fromAcc = accountMap[outTx.accountId];
      final toAcc = accountMap[match.accountId];
      candidates.add(
        MirrorPairCandidate(
          id: 'pair_${outTx.id}_${match.id}',
          outflowTx: outTx,
          inflowTx: match,
          fromAccountName: fromAcc?.name ?? 'Cuenta origen',
          toAccountName: toAcc?.name ?? 'Cuenta destino',
          amount: outTx.amount,
          confidenceLabel: 'Coincidencia exacta (monto, hora y concepto bancario)',
        ),
      );
    }
  }

  return candidates;
}

CashflowSummary calculateCashflowSummary({
  required List<Account> accounts,
  required List<TransactionRecord> transactions,
  required List<Debt> debts,
  required List<CategoryBudget> budgets,
}) {
  final cashOnlyTotal = accounts
      .where((a) => a.institution == AccountInstitution.efectivo)
      .fold<double>(0, (sum, a) => sum + a.balance);
  final nequiOnlyTotal = accounts
      .where((a) => a.institution == AccountInstitution.nequi)
      .fold<double>(0, (sum, a) => sum + a.balance);
  final banksSavingsTotal = accounts
      .where((a) =>
          a.institution == AccountInstitution.davibank ||
          a.institution == AccountInstitution.nubank)
      .fold<double>(0, (sum, a) => sum + a.balance);
  final totalLiquid = cashOnlyTotal + nequiOnlyTotal + banksSavingsTotal;
  final totalDebt = debts.fold<double>(0, (sum, d) => sum + d.balance);

  final inflowsByAcc = <String, double>{for (final a in accounts) a.id: 0};
  final outflowsByAcc = <String, double>{for (final a in accounts) a.id: 0};

  double realMonthlyExpenses = 0;
  double excludedTransferVolume = 0;
  double debtPaymentsThisMonth = 0;
  double monthlyIncome = 0;
  int recordedIncomeCount = 0;

  final spentByCategory = <String, double>{};
  final seenPairs = <String>{};

  for (final tx in transactions) {
    if (tx.type == TransactionType.transfer ||
        tx.transferStatus == TransferStatus.confirmedMirror) {
      final pairKey = (tx.linkedTransferId != null && tx.linkedTransferId!.isNotEmpty)
          ? ([tx.id, tx.linkedTransferId!]..sort()).join('_')
          : tx.id;
      if (seenPairs.add(pairKey)) {
        excludedTransferVolume += tx.amount;
      }
      continue;
    }

    if (tx.type == TransactionType.income) {
      monthlyIncome += tx.amount;
      recordedIncomeCount += 1;
      inflowsByAcc[tx.accountId] = (inflowsByAcc[tx.accountId] ?? 0) + tx.amount;
      continue;
    }

    if (tx.type == TransactionType.debtPayment) {
      debtPaymentsThisMonth += tx.amount;
      outflowsByAcc[tx.accountId] = (outflowsByAcc[tx.accountId] ?? 0) + tx.amount;
      continue;
    }

    if (tx.type == TransactionType.expense) {
      realMonthlyExpenses += tx.amount;
      outflowsByAcc[tx.accountId] = (outflowsByAcc[tx.accountId] ?? 0) + tx.amount;
      spentByCategory[tx.category] = (spentByCategory[tx.category] ?? 0) + tx.amount;
    }
  }

  final budgetStatuses = budgets.map((b) {
    final spent = spentByCategory[b.category] ?? 0;
    final remaining = b.monthlyLimit - spent;
    final percent = b.monthlyLimit > 0 ? ((spent / b.monthlyLimit) * 100).round() : 0;
    final status = percent > 100
        ? 'exceeded'
        : percent >= 85
            ? 'warning'
            : 'ok';
    return BudgetStatus(
      budget: b,
      spent: spent,
      remaining: remaining,
      percent: percent,
      status: status,
    );
  }).toList()
    ..sort((a, b) => b.percent.compareTo(a.percent));

  final overBudgetCount = budgetStatuses.where((b) => b.status == 'exceeded').length;

  final accountFlows = {
    for (final a in accounts)
      a.id: AccountFlowStat(
        accountId: a.id,
        inflow: inflowsByAcc[a.id] ?? 0,
        outflow: outflowsByAcc[a.id] ?? 0,
      ),
  };

  return CashflowSummary(
    totalLiquid: totalLiquid,
    cashOnlyTotal: cashOnlyTotal,
    nequiOnlyTotal: nequiOnlyTotal,
    banksSavingsTotal: banksSavingsTotal,
    totalDebt: totalDebt,
    monthlyIncome: monthlyIncome,
    recordedIncomeCount: recordedIncomeCount,
    realMonthlyExpenses: realMonthlyExpenses,
    excludedTransferVolume: excludedTransferVolume,
    debtPaymentsThisMonth: debtPaymentsThisMonth,
    freeCashflow: monthlyIncome - realMonthlyExpenses - debtPaymentsThisMonth,
    budgetStatuses: budgetStatuses,
    overBudgetCount: overBudgetCount,
    accountFlows: accountFlows,
  );
}

List<IncomeSourceBreakdown> calculateIncomeBreakdown(
  List<IncomeSource> sources,
  List<TransactionRecord> transactions,
) {
  final realIncomes = transactions
      .where((t) =>
          t.type == TransactionType.income &&
          t.transferStatus != TransferStatus.confirmedMirror)
      .toList();

  final sourceMap = {for (final s in sources) s.id: s};
  final totals = <String, double>{for (final s in sources) s.id: 0};
  final counts = <String, int>{for (final s in sources) s.id: 0};

  double otherTotal = 0;
  int otherCount = 0;

  for (final tx in realIncomes) {
    final key = tx.incomeSourceId;
    if (key != null && sourceMap.containsKey(key)) {
      totals[key] = (totals[key] ?? 0) + tx.amount;
      counts[key] = (counts[key] ?? 0) + 1;
    } else {
      otherTotal += tx.amount;
      otherCount += 1;
    }
  }

  final result = [
    for (final src in sources)
      IncomeSourceBreakdown(
        sourceId: src.id,
        sourceName: src.name,
        isActive: src.isActive,
        totalReceived: totals[src.id] ?? 0,
        paymentCount: counts[src.id] ?? 0,
      ),
    if (otherCount > 0)
      IncomeSourceBreakdown(
        sourceId: 'other',
        sourceName: 'Otros ingresos',
        isActive: true,
        totalReceived: otherTotal,
        paymentCount: otherCount,
      ),
  ];

  result.sort((a, b) => b.totalReceived.compareTo(a.totalReceived));
  return result;
}

({int months, double totalInterest, List<String> order}) _runPayoffSim(
  List<Debt> debts,
  DebtStrategy strategy,
  double extraBudget,
) {
  final active = debts.where((d) => d.balance > 0).toList();
  if (active.isEmpty) {
    return (months: 0, totalInterest: 0, order: const []);
  }

  active.sort((a, b) => strategy == DebtStrategy.avalanche
      ? b.aprEa.compareTo(a.aprEa)
      : a.balance.compareTo(b.balance));

  final balances = {for (final d in active) d.id: d.balance};
  final monthlyRates = {
    for (final d in active)
      d.id: d.aprEa > 0 ? math.pow(1 + d.aprEa / 100.0, 1 / 12.0).toDouble() - 1 : 0.0,
  };

  int month = 0;
  double totalInterest = 0;

  while (balances.values.any((b) => b > 1) && month < 120) {
    month += 1;
    double availableExtra = extraBudget;

    for (final d in active) {
      final current = balances[d.id] ?? 0;
      if (current <= 0) {
        availableExtra += d.minimumPayment;
        continue;
      }
      final interest = current * (monthlyRates[d.id] ?? 0);
      totalInterest += interest;
      final afterInterest = current + interest;
      final minPay = math.min(afterInterest, math.max(d.minimumPayment, interest + 10000));
      balances[d.id] = math.max(0, afterInterest - minPay);
    }

    for (final d in active) {
      if (availableExtra <= 0) break;
      final current = balances[d.id] ?? 0;
      if (current <= 0) continue;
      final apply = math.min(current, availableExtra);
      balances[d.id] = math.max(0, current - apply);
      availableExtra -= apply;
    }
  }

  return (
    months: month,
    totalInterest: totalInterest.roundToDouble(),
    order: active.map((d) => d.id).toList(),
  );
}

DebtPayoffPlan simulateDebtPayoff({
  required List<Debt> debts,
  required DebtStrategy strategy,
  required double extraMonthlyBudget,
}) {
  final baseline = _runPayoffSim(debts, strategy, 0);
  final accelerated = _runPayoffSim(debts, strategy, extraMonthlyBudget);

  return DebtPayoffPlan(
    strategy: strategy,
    extraMonthlyBudget: extraMonthlyBudget,
    totalMonths: accelerated.months,
    totalInterestPaid: accelerated.totalInterest,
    monthsSavedVsMinimum: math.max(0, baseline.months - accelerated.months),
    interestSavedVsMinimum: math.max(0, baseline.totalInterest - accelerated.totalInterest),
    priorityOrderIds: accelerated.order,
  );
}

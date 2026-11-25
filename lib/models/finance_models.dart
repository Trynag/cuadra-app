import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountInstitution { efectivo, nequi, davibank, nubank }

enum AccountKind { cash, wallet, savings }

enum DebtInstitution { davibank, nubank, addi, sistecredito }

enum DebtKind { creditCard, bnpl }

enum TransactionType { expense, income, transfer, debtPayment }

enum TransactionSource { manual, sync, sms }

enum TransferStatus { none, pendingReview, confirmedMirror }

enum DebtStrategy { avalanche, snowball }

enum IncomeFrequency { daily, biweekly, monthly, occasional }

extension AccountInstitutionX on AccountInstitution {
  String get wire => name;
  String get shortCode => switch (this) {
        AccountInstitution.efectivo => 'EF',
        AccountInstitution.nequi => 'NQ',
        AccountInstitution.davibank => 'DB',
        AccountInstitution.nubank => 'NU',
      };

  static AccountInstitution fromWire(String value) => switch (value) {
        'efectivo' => AccountInstitution.efectivo,
        'nequi' => AccountInstitution.nequi,
        'davibank' => AccountInstitution.davibank,
        'nubank' => AccountInstitution.nubank,
        _ => AccountInstitution.efectivo,
      };
}

extension AccountKindX on AccountKind {
  String get wire => name;
  static AccountKind fromWire(String value) => switch (value) {
        'cash' => AccountKind.cash,
        'wallet' => AccountKind.wallet,
        'savings' => AccountKind.savings,
        _ => AccountKind.wallet,
      };
}

extension DebtInstitutionX on DebtInstitution {
  String get wire => name;
  String get shortCode => switch (this) {
        DebtInstitution.davibank => 'DB',
        DebtInstitution.nubank => 'NU',
        DebtInstitution.addi => 'AD',
        DebtInstitution.sistecredito => 'SC',
      };

  static DebtInstitution fromWire(String value) => switch (value) {
        'davibank' => DebtInstitution.davibank,
        'nubank' => DebtInstitution.nubank,
        'addi' => DebtInstitution.addi,
        'sistecredito' => DebtInstitution.sistecredito,
        _ => DebtInstitution.davibank,
      };
}

extension DebtKindX on DebtKind {
  String get wire => this == DebtKind.creditCard ? 'credit_card' : 'bnpl';
  static DebtKind fromWire(String value) =>
      value == 'bnpl' ? DebtKind.bnpl : DebtKind.creditCard;
}

extension TransactionTypeX on TransactionType {
  String get wire => switch (this) {
        TransactionType.expense => 'expense',
        TransactionType.income => 'income',
        TransactionType.transfer => 'transfer',
        TransactionType.debtPayment => 'debt_payment',
      };

  static TransactionType fromWire(String value) => switch (value) {
        'expense' => TransactionType.expense,
        'income' => TransactionType.income,
        'transfer' => TransactionType.transfer,
        'debt_payment' => TransactionType.debtPayment,
        _ => TransactionType.expense,
      };
}

extension TransactionSourceX on TransactionSource {
  String get wire => name;
  static TransactionSource fromWire(String value) => switch (value) {
        'sync' => TransactionSource.sync,
        'sms' => TransactionSource.sms,
        _ => TransactionSource.manual,
      };
}

extension TransferStatusX on TransferStatus {
  String get wire => switch (this) {
        TransferStatus.none => 'none',
        TransferStatus.pendingReview => 'pending_review',
        TransferStatus.confirmedMirror => 'confirmed_mirror',
      };

  static TransferStatus fromWire(String value) => switch (value) {
        'pending_review' => TransferStatus.pendingReview,
        'confirmed_mirror' => TransferStatus.confirmedMirror,
        _ => TransferStatus.none,
      };
}

extension DebtStrategyX on DebtStrategy {
  String get wire => name;
  String get label => this == DebtStrategy.avalanche ? 'Avalancha' : 'Bola de nieve';
  static DebtStrategy fromWire(String value) =>
      value == 'snowball' ? DebtStrategy.snowball : DebtStrategy.avalanche;
}

extension IncomeFrequencyX on IncomeFrequency {
  String get wire => name;
  String get label => switch (this) {
        IncomeFrequency.daily => 'Pago diario',
        IncomeFrequency.biweekly => 'Pago quincenal',
        IncomeFrequency.monthly => 'Pago mensual',
        IncomeFrequency.occasional => 'Ocasional / Extra',
      };

  static IncomeFrequency fromWire(String value) => switch (value) {
        'daily' => IncomeFrequency.daily,
        'biweekly' => IncomeFrequency.biweekly,
        'monthly' => IncomeFrequency.monthly,
        'occasional' => IncomeFrequency.occasional,
        _ => IncomeFrequency.occasional,
      };
}

class Account {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.institution,
    required this.kind,
    required this.balance,
    required this.lastSyncedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountInstitution institution;
  final AccountKind kind;
  final double balance;
  final String lastSyncedAt;

  Account copyWith({
    String? userId,
    String? name,
    double? balance,
    String? lastSyncedAt,
  }) =>
      Account(
        id: id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        institution: institution,
        kind: kind,
        balance: balance ?? this.balance,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        institution: AccountInstitutionX.fromWire(map['institution'] as String),
        kind: AccountKindX.fromWire(map['kind'] as String),
        balance: (map['balance'] as num).toDouble(),
        lastSyncedAt: map['lastSyncedAt'] as String? ?? 'Actualizado ahora',
      );

  Map<String, dynamic> toFirestore({required bool isCreate}) => {
        'id': id,
        'userId': userId,
        'name': name,
        'institution': institution.wire,
        'kind': kind.wire,
        'balance': balance,
        'lastSyncedAt': lastSyncedAt,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class IncomeSource {
  const IncomeSource({
    required this.id,
    required this.userId,
    required this.name,
    required this.frequency,
    required this.defaultAmount,
    required this.defaultAccountId,
    required this.isActive,
    required this.notes,
  });

  final String id;
  final String userId;
  final String name;
  final IncomeFrequency frequency;
  final double defaultAmount;
  final String defaultAccountId;
  final bool isActive;
  final String notes;

  IncomeSource copyWith({
    String? userId,
    String? name,
    IncomeFrequency? frequency,
    double? defaultAmount,
    String? defaultAccountId,
    bool? isActive,
    String? notes,
  }) =>
      IncomeSource(
        id: id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        frequency: frequency ?? this.frequency,
        defaultAmount: defaultAmount ?? this.defaultAmount,
        defaultAccountId: defaultAccountId ?? this.defaultAccountId,
        isActive: isActive ?? this.isActive,
        notes: notes ?? this.notes,
      );

  factory IncomeSource.fromMap(Map<String, dynamic> map) => IncomeSource(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        frequency: IncomeFrequencyX.fromWire(map['frequency'] as String),
        defaultAmount: (map['defaultAmount'] as num).toDouble(),
        defaultAccountId: map['defaultAccountId'] as String,
        isActive: map['isActive'] as bool? ?? true,
        notes: map['notes'] as String? ?? '',
      );

  Map<String, dynamic> toFirestore({required bool isCreate}) => {
        'id': id,
        'userId': userId,
        'name': name,
        'frequency': frequency.wire,
        'defaultAmount': defaultAmount,
        'defaultAccountId': defaultAccountId,
        'isActive': isActive,
        'notes': notes,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class TransactionRecord {
  const TransactionRecord({
    required this.id,
    required this.userId,
    required this.accountId,
    this.toAccountId,
    this.debtId,
    this.incomeSourceId,
    this.incomeReason,
    required this.type,
    required this.amount,
    required this.description,
    required this.category,
    required this.dateIso,
    required this.source,
    required this.isSpontaneous,
    this.linkedTransferId,
    required this.transferStatus,
  });

  final String id;
  final String userId;
  final String accountId;
  final String? toAccountId;
  final String? debtId;
  final String? incomeSourceId;
  final String? incomeReason;
  final TransactionType type;
  final double amount;
  final String description;
  final String category;
  final String dateIso;
  final TransactionSource source;
  final bool isSpontaneous;
  final String? linkedTransferId;
  final TransferStatus transferStatus;

  TransactionRecord copyWith({
    String? userId,
    String? toAccountId,
    TransactionType? type,
    String? category,
    String? linkedTransferId,
    TransferStatus? transferStatus,
  }) =>
      TransactionRecord(
        id: id,
        userId: userId ?? this.userId,
        accountId: accountId,
        toAccountId: toAccountId ?? this.toAccountId,
        debtId: debtId,
        incomeSourceId: incomeSourceId,
        incomeReason: incomeReason,
        type: type ?? this.type,
        amount: amount,
        description: description,
        category: category ?? this.category,
        dateIso: dateIso,
        source: source,
        isSpontaneous: isSpontaneous,
        linkedTransferId: linkedTransferId ?? this.linkedTransferId,
        transferStatus: transferStatus ?? this.transferStatus,
      );

  factory TransactionRecord.fromMap(Map<String, dynamic> map) => TransactionRecord(
        id: map['id'] as String,
        userId: map['userId'] as String,
        accountId: map['accountId'] as String,
        toAccountId: map['toAccountId'] as String?,
        debtId: map['debtId'] as String?,
        incomeSourceId: map['incomeSourceId'] as String?,
        incomeReason: map['incomeReason'] as String?,
        type: TransactionTypeX.fromWire(map['type'] as String),
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String,
        category: map['category'] as String,
        dateIso: map['dateIso'] as String,
        source: TransactionSourceX.fromWire(map['source'] as String),
        isSpontaneous: map['isSpontaneous'] as bool? ?? false,
        linkedTransferId: map['linkedTransferId'] as String?,
        transferStatus: TransferStatusX.fromWire(map['transferStatus'] as String? ?? 'none'),
      );

  Map<String, dynamic> toFirestore({required bool isCreate}) => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        if (toAccountId != null && toAccountId!.isNotEmpty) 'toAccountId': toAccountId,
        if (debtId != null && debtId!.isNotEmpty) 'debtId': debtId,
        if (incomeSourceId != null && incomeSourceId!.isNotEmpty)
          'incomeSourceId': incomeSourceId,
        if (incomeReason != null && incomeReason!.isNotEmpty) 'incomeReason': incomeReason,
        'type': type.wire,
        'amount': amount,
        'description': description,
        'category': category,
        'dateIso': dateIso,
        'source': source.wire,
        'isSpontaneous': isSpontaneous,
        if (linkedTransferId != null && linkedTransferId!.isNotEmpty)
          'linkedTransferId': linkedTransferId,
        'transferStatus': transferStatus.wire,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class Debt {
  const Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.institution,
    required this.kind,
    required this.balance,
    required this.creditLimit,
    required this.aprEa,
    required this.minimumPayment,
    required this.dueDay,
    required this.remainingInstallments,
  });

  final String id;
  final String userId;
  final String name;
  final DebtInstitution institution;
  final DebtKind kind;
  final double balance;
  final double creditLimit;
  final double aprEa;
  final double minimumPayment;
  final int dueDay;
  final int remainingInstallments;

  Debt copyWith({
    String? userId,
    double? balance,
    int? remainingInstallments,
  }) =>
      Debt(
        id: id,
        userId: userId ?? this.userId,
        name: name,
        institution: institution,
        kind: kind,
        balance: balance ?? this.balance,
        creditLimit: creditLimit,
        aprEa: aprEa,
        minimumPayment: minimumPayment,
        dueDay: dueDay,
        remainingInstallments: remainingInstallments ?? this.remainingInstallments,
      );

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
        id: map['id'] as String,
        userId: map['userId'] as String,
        name: map['name'] as String,
        institution: DebtInstitutionX.fromWire(map['institution'] as String),
        kind: DebtKindX.fromWire(map['kind'] as String),
        balance: (map['balance'] as num).toDouble(),
        creditLimit: (map['creditLimit'] as num).toDouble(),
        aprEa: (map['aprEa'] as num).toDouble(),
        minimumPayment: (map['minimumPayment'] as num).toDouble(),
        dueDay: (map['dueDay'] as num).toInt(),
        remainingInstallments: (map['remainingInstallments'] as num).toInt(),
      );

  Map<String, dynamic> toFirestore({required bool isCreate}) => {
        'id': id,
        'userId': userId,
        'name': name,
        'institution': institution.wire,
        'kind': kind.wire,
        'balance': balance,
        'creditLimit': creditLimit,
        'aprEa': aprEa,
        'minimumPayment': minimumPayment,
        'dueDay': dueDay,
        'remainingInstallments': remainingInstallments,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class CategoryBudget {
  const CategoryBudget({
    required this.id,
    required this.userId,
    required this.category,
    required this.monthlyLimit,
  });

  final String id;
  final String userId;
  final String category;
  final double monthlyLimit;

  CategoryBudget copyWith({String? userId, double? monthlyLimit}) => CategoryBudget(
        id: id,
        userId: userId ?? this.userId,
        category: category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      );

  factory CategoryBudget.fromMap(Map<String, dynamic> map) => CategoryBudget(
        id: map['id'] as String,
        userId: map['userId'] as String,
        category: map['category'] as String,
        monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
      );

  Map<String, dynamic> toFirestore({required bool isCreate}) => {
        'id': id,
        'userId': userId,
        'category': category,
        'monthlyLimit': monthlyLimit,
        if (isCreate) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class AccountFlowStat {
  const AccountFlowStat({
    required this.accountId,
    required this.inflow,
    required this.outflow,
  });

  final String accountId;
  final double inflow;
  final double outflow;
}

class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.percent,
    required this.status,
  });

  final CategoryBudget budget;
  final double spent;
  final double remaining;
  final int percent;
  final String status; // 'ok' | 'warning' | 'exceeded'
}

class IncomeSourceBreakdown {
  const IncomeSourceBreakdown({
    required this.sourceId,
    required this.sourceName,
    required this.isActive,
    required this.totalReceived,
    required this.paymentCount,
  });

  final String sourceId;
  final String sourceName;
  final bool isActive;
  final double totalReceived;
  final int paymentCount;
}

class MirrorPairCandidate {
  const MirrorPairCandidate({
    required this.id,
    required this.outflowTx,
    required this.inflowTx,
    required this.fromAccountName,
    required this.toAccountName,
    required this.amount,
    required this.confidenceLabel,
  });

  final String id;
  final TransactionRecord outflowTx;
  final TransactionRecord inflowTx;
  final String fromAccountName;
  final String toAccountName;
  final double amount;
  final String confidenceLabel;
}

class CashflowSummary {
  const CashflowSummary({
    required this.totalLiquid,
    required this.cashOnlyTotal,
    required this.nequiOnlyTotal,
    required this.banksSavingsTotal,
    required this.totalDebt,
    required this.monthlyIncome,
    required this.recordedIncomeCount,
    required this.realMonthlyExpenses,
    required this.excludedTransferVolume,
    required this.debtPaymentsThisMonth,
    required this.freeCashflow,
    required this.budgetStatuses,
    required this.overBudgetCount,
    required this.accountFlows,
  });

  final double totalLiquid;
  final double cashOnlyTotal;
  final double nequiOnlyTotal;
  final double banksSavingsTotal;
  final double totalDebt;
  final double monthlyIncome;
  final int recordedIncomeCount;
  final double realMonthlyExpenses;
  final double excludedTransferVolume;
  final double debtPaymentsThisMonth;
  final double freeCashflow;
  final List<BudgetStatus> budgetStatuses;
  final int overBudgetCount;
  final Map<String, AccountFlowStat> accountFlows;
}

class DebtPayoffPlan {
  const DebtPayoffPlan({
    required this.strategy,
    required this.extraMonthlyBudget,
    required this.totalMonths,
    required this.totalInterestPaid,
    required this.monthsSavedVsMinimum,
    required this.interestSavedVsMinimum,
    required this.priorityOrderIds,
  });

  final DebtStrategy strategy;
  final double extraMonthlyBudget;
  final int totalMonths;
  final double totalInterestPaid;
  final int monthsSavedVsMinimum;
  final double interestSavedVsMinimum;
  final List<String> priorityOrderIds;
}

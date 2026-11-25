import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/seed_data.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../services/firestore_repository.dart';

class FinanceController extends ChangeNotifier {
  FinanceController({required bool firebaseAvailable})
      : _firebaseAvailable = firebaseAvailable,
        _accounts = SeedData.accounts('local_user'),
        _transactions = SeedData.transactions('local_user'),
        _debts = SeedData.debts('local_user'),
        _budgets = SeedData.budgets('local_user'),
        _incomeSources = SeedData.incomeSources('local_user') {
    if (_firebaseAvailable) {
      _repo = FirestoreRepository();
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    }
  }

  final bool _firebaseAvailable;
  FirestoreRepository? _repo;
  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<dynamic>> _cloudSubs = [];

  User? _user;
  List<Account> _accounts;
  List<TransactionRecord> _transactions;
  List<Debt> _debts;
  List<CategoryBudget> _budgets;
  List<IncomeSource> _incomeSources;
  DebtStrategy _debtStrategy = DebtStrategy.avalanche;
  double _extraDebtBudget = 300000;
  String? _notice;

  bool get isCloudMode => _firebaseAvailable && _user != null;
  User? get user => _user;
  List<Account> get accounts => _accounts;
  List<TransactionRecord> get transactions => _transactions;
  List<Debt> get debts => _debts;
  List<CategoryBudget> get budgets => _budgets;
  List<IncomeSource> get incomeSources => _incomeSources;
  DebtStrategy get debtStrategy => _debtStrategy;
  double get extraDebtBudget => _extraDebtBudget;
  String? get notice => _notice;

  List<MirrorPairCandidate> get pendingMirrorPairs =>
      detectInternalTransfers(_transactions, _accounts);

  CashflowSummary get summary => calculateCashflowSummary(
        accounts: _accounts,
        transactions: _transactions,
        debts: _debts,
        budgets: _budgets,
      );

  List<IncomeSourceBreakdown> get incomeBreakdown =>
      calculateIncomeBreakdown(_incomeSources, _transactions);

  DebtPayoffPlan get debtPlan => simulateDebtPayoff(
        debts: _debts,
        strategy: _debtStrategy,
        extraMonthlyBudget: _extraDebtBudget,
      );

  void clearNotice() {
    _notice = null;
    notifyListeners();
  }

  Future<void> _onAuthChanged(User? nextUser) async {
    for (final sub in _cloudSubs) {
      await sub.cancel();
    }
    _cloudSubs.clear();
    _user = nextUser;

    if (nextUser == null || _repo == null) {
      notifyListeners();
      return;
    }

    final exists = await _repo!.hasUserProfile(nextUser.uid);
    if (!exists) {
      await _repo!.bootstrapUserData(
        uid: nextUser.uid,
        displayName: nextUser.displayName ?? 'Mi Espacio Financiero',
        debtStrategy: _debtStrategy,
        extraDebtBudget: _extraDebtBudget,
        monthlyIncome: summary.monthlyIncome,
        completedHabitIds: const [],
        accounts: _accounts,
        transactions: _transactions,
        debts: _debts,
        budgets: _budgets,
        incomeSources: _incomeSources,
      );
    }

    _cloudSubs.addAll([
      _repo!.watchAccounts(nextUser.uid).listen((data) {
        _accounts = data;
        notifyListeners();
      }),
      _repo!.watchTransactions(nextUser.uid).listen((data) {
        _transactions = data;
        notifyListeners();
      }),
      _repo!.watchDebts(nextUser.uid).listen((data) {
        _debts = data;
        notifyListeners();
      }),
      _repo!.watchBudgets(nextUser.uid).listen((data) {
        _budgets = data;
        notifyListeners();
      }),
      _repo!.watchIncomeSources(nextUser.uid).listen((data) {
        _incomeSources = data;
        notifyListeners();
      }),
    ]);

    _notice = 'Sincronizado en tiempo real con Firebase Firestore.';
    notifyListeners();
  }

  Future<void> addTransaction({
    required String accountId,
    String? toAccountId,
    String? debtId,
    String? incomeSourceId,
    String? incomeReason,
    required TransactionType type,
    required double amount,
    required String description,
    String? category,
    DateTime? date,
  }) async {
    final uid = _user?.uid ?? 'local_user';
    final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedCategory = switch (type) {
      TransactionType.transfer => 'Transferencia interna',
      TransactionType.income => 'Ingreso / Nómina',
      TransactionType.debtPayment => 'Pago de deuda',
      TransactionType.expense =>
        category ?? categorizeTransaction(description, accountId: accountId, amount: amount),
    };

    final tx = TransactionRecord(
      id: txId,
      userId: uid,
      accountId: accountId,
      toAccountId: type == TransactionType.transfer ? toAccountId : null,
      debtId: type == TransactionType.debtPayment ? debtId : null,
      incomeSourceId: type == TransactionType.income ? incomeSourceId : null,
      incomeReason: type == TransactionType.income ? (incomeReason ?? description) : null,
      type: type,
      amount: amount,
      description: description,
      category: resolvedCategory,
      dateIso: (date ?? DateTime.now()).toIso8601String(),
      source: TransactionSource.manual,
      isSpontaneous: type == TransactionType.expense && isSpontaneousAccount(accountId),
      transferStatus:
          type == TransactionType.transfer ? TransferStatus.confirmedMirror : TransferStatus.none,
    );

    final srcAcc = _accounts.firstWhere((a) => a.id == accountId);
    final nextSrcBalance =
        type == TransactionType.income ? srcAcc.balance + amount : srcAcc.balance - amount;

    Account? dstAcc;
    double? nextDstBalance;
    if (type == TransactionType.transfer && toAccountId != null) {
      dstAcc = _accounts.firstWhere((a) => a.id == toAccountId);
      nextDstBalance = dstAcc.balance + amount;
    }

    Debt? targetDebt;
    double? nextDebtBalance;
    int? nextInstallments;
    if (type == TransactionType.debtPayment && debtId != null) {
      targetDebt = _debts.firstWhere((d) => d.id == debtId);
      nextDebtBalance = math.max(0, targetDebt.balance - amount);
      nextInstallments =
          nextDebtBalance <= 0 ? 0 : math.max(1, targetDebt.remainingInstallments - 1);
    }

    if (isCloudMode && _repo != null) {
      await _repo!.createTransactionWithBalanceUpdates(
        uid: uid,
        tx: tx,
        sourceAccountId: srcAcc.id,
        nextSourceBalance: nextSrcBalance,
        targetAccountId: dstAcc?.id,
        nextTargetBalance: nextDstBalance,
        debtId: targetDebt?.id,
        nextDebtBalance: nextDebtBalance,
        nextRemainingInstallments: nextInstallments,
      );
      return;
    }

    _transactions = [tx, ..._transactions];
    _accounts = _accounts.map((a) {
      if (a.id == srcAcc.id) {
        return a.copyWith(balance: nextSrcBalance, lastSyncedAt: 'Actualizado ahora');
      }
      if (dstAcc != null && a.id == dstAcc.id && nextDstBalance != null) {
        return a.copyWith(balance: nextDstBalance, lastSyncedAt: 'Actualizado ahora');
      }
      return a;
    }).toList();

    if (targetDebt != null && nextDebtBalance != null && nextInstallments != null) {
      _debts = _debts
          .map((d) => d.id == targetDebt!.id
              ? d.copyWith(
                  balance: nextDebtBalance,
                  remainingInstallments: nextInstallments,
                )
              : d)
          .toList();
    }

    _notice = type == TransactionType.income
        ? 'Ingreso registrado: +${formatCOP(amount)} sumado a ${srcAcc.name}.'
        : type == TransactionType.transfer
            ? 'Traslado registrado sin duplicar tu gasto mensual.'
            : 'Movimiento guardado: ${formatCOP(amount)}.';
    notifyListeners();
  }

  Future<void> reconcileMirrorPair(MirrorPairCandidate pair) async {
    if (isCloudMode && _repo != null) {
      await _repo!.reconcileMirrorPair(uid: _user!.uid, pair: pair);
      return;
    }

    _transactions = _transactions.map((t) {
      if (t.id == pair.outflowTx.id) {
        return t.copyWith(
          type: TransactionType.transfer,
          transferStatus: TransferStatus.confirmedMirror,
          linkedTransferId: pair.inflowTx.id,
          toAccountId: pair.inflowTx.accountId,
          category: 'Transferencia interna',
        );
      }
      if (t.id == pair.inflowTx.id) {
        return t.copyWith(
          type: TransactionType.transfer,
          transferStatus: TransferStatus.confirmedMirror,
          linkedTransferId: pair.outflowTx.id,
          toAccountId: pair.inflowTx.accountId,
          category: 'Transferencia interna',
        );
      }
      return t;
    }).toList();

    _notice =
        'Traslado ${pair.fromAccountName} → ${pair.toAccountName} conciliado sin duplicados.';
    notifyListeners();
  }

  Future<void> addIncomeSource({
    required String name,
    required IncomeFrequency frequency,
    required double defaultAmount,
    required String defaultAccountId,
    String notes = '',
  }) async {
    final uid = _user?.uid ?? 'local_user';
    final src = IncomeSource(
      id: 'src_${DateTime.now().millisecondsSinceEpoch}',
      userId: uid,
      name: name.trim(),
      frequency: frequency,
      defaultAmount: defaultAmount,
      defaultAccountId: defaultAccountId,
      isActive: true,
      notes: notes.trim(),
    );

    if (isCloudMode && _repo != null) {
      await _repo!.addIncomeSource(uid, src);
      return;
    }

    _incomeSources = [..._incomeSources, src];
    _notice = 'Trabajo "${src.name}" agregado a tus fuentes de ingreso.';
    notifyListeners();
  }

  Future<void> toggleIncomeSourceActive(String sourceId) async {
    final target = _incomeSources.firstWhere((s) => s.id == sourceId);
    final nextActive = !target.isActive;

    if (isCloudMode && _repo != null) {
      await _repo!.toggleIncomeSourceActive(_user!.uid, sourceId, nextActive);
      return;
    }

    _incomeSources = _incomeSources
        .map((s) => s.id == sourceId ? s.copyWith(isActive: nextActive) : s)
        .toList();
    _notice = nextActive
        ? '"${target.name}" reactivado.'
        : '"${target.name}" pausado. Tu historial de pagos se mantiene intacto.';
    notifyListeners();
  }

  Future<void> updateBudgetLimit(String budgetId, double monthlyLimit) async {
    if (isCloudMode && _repo != null) {
      await _repo!.updateBudgetLimit(_user!.uid, budgetId, monthlyLimit);
      return;
    }
    _budgets = _budgets
        .map((b) => b.id == budgetId ? b.copyWith(monthlyLimit: monthlyLimit) : b)
        .toList();
    notifyListeners();
  }

  Future<void> updateDebtStrategy(DebtStrategy strategy, double extraBudget) async {
    _debtStrategy = strategy;
    _extraDebtBudget = extraBudget;
    if (isCloudMode && _repo != null) {
      await _repo!.updateDebtStrategy(_user!.uid, strategy, extraBudget);
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final sub in _cloudSubs) {
      sub.cancel();
    }
    super.dispose();
  }
}

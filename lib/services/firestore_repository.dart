import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/firebase_constants.dart';
import '../models/finance_models.dart';

/// Repositorio Firestore compatible 1:1 con `firestore.rules` y `firebase-blueprint.json`
/// de la versión web (React + Vite), apuntando exactamente a la misma base de datos.
class FirestoreRepository {
  FirestoreRepository()
      : _db = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: FirebaseConstants.firestoreDatabaseId,
        );

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _accountsCol(String uid) =>
      _userDoc(uid).collection('accounts');

  CollectionReference<Map<String, dynamic>> _transactionsCol(String uid) =>
      _userDoc(uid).collection('transactions');

  CollectionReference<Map<String, dynamic>> _debtsCol(String uid) =>
      _userDoc(uid).collection('debts');

  CollectionReference<Map<String, dynamic>> _budgetsCol(String uid) =>
      _userDoc(uid).collection('budgets');

  CollectionReference<Map<String, dynamic>> _incomeSourcesCol(String uid) =>
      _userDoc(uid).collection('incomeSources');

  Future<bool> hasUserProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    return snap.exists;
  }

  /// Inicializa atómicamente el espacio del usuario respetando `userDocExistsOrCreated`.
  Future<void> bootstrapUserData({
    required String uid,
    required String displayName,
    required DebtStrategy debtStrategy,
    required double extraDebtBudget,
    required double monthlyIncome,
    required List<String> completedHabitIds,
    required List<Account> accounts,
    required List<TransactionRecord> transactions,
    required List<Debt> debts,
    required List<CategoryBudget> budgets,
    required List<IncomeSource> incomeSources,
  }) async {
    final batch = _db.batch();
    batch.set(_userDoc(uid), {
      'uid': uid,
      'displayName': displayName.isEmpty ? 'Mi Espacio Financiero' : displayName,
      'debtStrategy': debtStrategy.wire,
      'extraDebtBudget': extraDebtBudget,
      'monthlyIncome': monthlyIncome,
      'completedHabitIds': completedHabitIds.take(30).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final acc in accounts) {
      batch.set(
        _accountsCol(uid).doc(acc.id),
        acc.copyWith(userId: uid).toFirestore(isCreate: true),
      );
    }
    for (final tx in transactions) {
      batch.set(
        _transactionsCol(uid).doc(tx.id),
        tx.copyWith(userId: uid).toFirestore(isCreate: true),
      );
    }
    for (final d in debts) {
      batch.set(
        _debtsCol(uid).doc(d.id),
        d.copyWith(userId: uid).toFirestore(isCreate: true),
      );
    }
    for (final b in budgets) {
      batch.set(
        _budgetsCol(uid).doc(b.id),
        b.copyWith(userId: uid).toFirestore(isCreate: true),
      );
    }
    for (final src in incomeSources) {
      batch.set(
        _incomeSourcesCol(uid).doc(src.id),
        src.copyWith(userId: uid).toFirestore(isCreate: true),
      );
    }

    await batch.commit();
  }

  // Todas las consultas `list` incluyen `.where('userId', isEqualTo: uid)` por reglas de seguridad.
  Stream<List<Account>> watchAccounts(String uid) => _accountsCol(uid)
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Account.fromMap(d.data())).toList());

  Stream<List<TransactionRecord>> watchTransactions(String uid) => _transactionsCol(uid)
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => TransactionRecord.fromMap(d.data())).toList();
        list.sort((a, b) => b.dateIso.compareTo(a.dateIso));
        return list;
      });

  Stream<List<Debt>> watchDebts(String uid) => _debtsCol(uid)
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Debt.fromMap(d.data())).toList());

  Stream<List<CategoryBudget>> watchBudgets(String uid) => _budgetsCol(uid)
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => CategoryBudget.fromMap(d.data())).toList());

  Stream<List<IncomeSource>> watchIncomeSources(String uid) => _incomeSourcesCol(uid)
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) => snap.docs.map((d) => IncomeSource.fromMap(d.data())).toList());

  Future<void> createTransactionWithBalanceUpdates({
    required String uid,
    required TransactionRecord tx,
    required String sourceAccountId,
    required double nextSourceBalance,
    String? targetAccountId,
    double? nextTargetBalance,
    String? debtId,
    double? nextDebtBalance,
    int? nextRemainingInstallments,
  }) async {
    final batch = _db.batch();
    batch.set(
      _transactionsCol(uid).doc(tx.id),
      tx.copyWith(userId: uid).toFirestore(isCreate: true),
    );
    batch.update(_accountsCol(uid).doc(sourceAccountId), {
      'balance': nextSourceBalance,
      'lastSyncedAt': 'Actualizado ahora',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (targetAccountId != null && nextTargetBalance != null) {
      batch.update(_accountsCol(uid).doc(targetAccountId), {
        'balance': nextTargetBalance,
        'lastSyncedAt': 'Actualizado ahora',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    if (debtId != null && nextDebtBalance != null && nextRemainingInstallments != null) {
      batch.update(_debtsCol(uid).doc(debtId), {
        'balance': nextDebtBalance,
        'remainingInstallments': nextRemainingInstallments,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> reconcileMirrorPair({
    required String uid,
    required MirrorPairCandidate pair,
  }) async {
    final batch = _db.batch();
    batch.update(_transactionsCol(uid).doc(pair.outflowTx.id), {
      'type': 'transfer',
      'transferStatus': 'confirmed_mirror',
      'linkedTransferId': pair.inflowTx.id,
      'toAccountId': pair.inflowTx.accountId,
      'category': 'Transferencia interna',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_transactionsCol(uid).doc(pair.inflowTx.id), {
      'type': 'transfer',
      'transferStatus': 'confirmed_mirror',
      'linkedTransferId': pair.outflowTx.id,
      'toAccountId': pair.inflowTx.accountId,
      'category': 'Transferencia interna',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> addIncomeSource(String uid, IncomeSource source) =>
      _incomeSourcesCol(uid)
          .doc(source.id)
          .set(source.copyWith(userId: uid).toFirestore(isCreate: true));

  Future<void> toggleIncomeSourceActive(String uid, String sourceId, bool isActive) =>
      _incomeSourcesCol(uid).doc(sourceId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteIncomeSource(String uid, String sourceId) =>
      _incomeSourcesCol(uid).doc(sourceId).delete();

  Future<void> updateBudgetLimit(String uid, String budgetId, double monthlyLimit) =>
      _budgetsCol(uid).doc(budgetId).update({
        'monthlyLimit': monthlyLimit,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateDebtStrategy(String uid, DebtStrategy strategy, double extraBudget) =>
      _userDoc(uid).update({
        'debtStrategy': strategy.wire,
        'extraDebtBudget': extraBudget,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

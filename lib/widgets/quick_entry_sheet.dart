import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/finance_models.dart';
import '../services/finance_engine.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';

Future<void> showQuickEntrySheet(
  BuildContext context, {
  TransactionType initialMode = TransactionType.expense,
  String? initialAccountId,
  String? initialIncomeSourceId,
  String? initialDebtId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _QuickEntryForm(
        initialMode: initialMode,
        initialAccountId: initialAccountId,
        initialIncomeSourceId: initialIncomeSourceId,
        initialDebtId: initialDebtId,
      ),
    ),
  );
}

class _QuickEntryForm extends StatefulWidget {
  const _QuickEntryForm({
    required this.initialMode,
    this.initialAccountId,
    this.initialIncomeSourceId,
    this.initialDebtId,
  });

  final TransactionType initialMode;
  final String? initialAccountId;
  final String? initialIncomeSourceId;
  final String? initialDebtId;

  @override
  State<_QuickEntryForm> createState() => _QuickEntryFormState();
}

class _QuickEntryFormState extends State<_QuickEntryForm> {
  late TransactionType _mode;
  late String _accountId;
  String _toAccountId = 'acc_nequi';
  String? _incomeSourceId;
  String? _debtId;
  String _category = 'Comida fuera';
  DateTime _selectedDate = DateTime.now();

  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<FinanceController>();
    _mode = widget.initialMode;
    _accountId = widget.initialAccountId ?? 'acc_nequi';
    _debtId = widget.initialDebtId ?? (ctrl.debts.isNotEmpty ? ctrl.debts.first.id : null);

    if (_mode == TransactionType.income) {
      final active = ctrl.incomeSources.where((s) => s.isActive).toList();
      final matched = widget.initialIncomeSourceId != null
          ? active.where((s) => s.id == widget.initialIncomeSourceId).firstOrNull
          : active.firstOrNull;
      if (matched != null) {
        _applyIncomeSource(matched);
      }
    }
  }

  void _applyIncomeSource(IncomeSource src) {
    _incomeSourceId = src.id;
    _accountId = src.defaultAccountId;
    if (src.defaultAmount > 0) {
      _amountCtrl.text = src.defaultAmount.round().toString();
    }
    _descCtrl.text = src.frequency == IncomeFrequency.daily
        ? 'Jornada diaria — ${src.name}'
        : 'Pago ${src.name}';
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido en pesos colombianos.');
      return;
    }
    if (_mode == TransactionType.transfer && _accountId == _toAccountId) {
      setState(() => _error = 'La cuenta origen y destino deben ser distintas.');
      return;
    }

    final ctrl = context.read<FinanceController>();
    final cleanDesc = _descCtrl.text.trim().isEmpty
        ? switch (_mode) {
            TransactionType.income => 'Ingreso recibido',
            TransactionType.transfer => 'Traslado entre cuentas propias',
            TransactionType.debtPayment => 'Abono a deuda',
            TransactionType.expense => 'Gasto diario',
          }
        : _descCtrl.text.trim();

    final src = _incomeSourceId == null
        ? null
        : ctrl.incomeSources.where((s) => s.id == _incomeSourceId).firstOrNull;

    await ctrl.addTransaction(
      accountId: _accountId,
      toAccountId: _mode == TransactionType.transfer ? _toAccountId : null,
      debtId: _mode == TransactionType.debtPayment ? _debtId : null,
      incomeSourceId: _mode == TransactionType.income ? _incomeSourceId : null,
      incomeReason: _mode == TransactionType.income ? cleanDesc : null,
      type: _mode,
      amount: amount,
      description: _mode == TransactionType.income && src != null
          ? '${src.name} — $cleanDesc'
          : cleanDesc,
      category: _mode == TransactionType.expense ? _category : null,
      date: _selectedDate,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();
    final activeSources = ctrl.incomeSources.where((s) => s.isActive).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: CuadraTheme.slate200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              'Registro rápido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('Gasto')),
                ButtonSegment(value: TransactionType.income, label: Text('Ingreso')),
                ButtonSegment(value: TransactionType.transfer, label: Text('Traslado')),
                ButtonSegment(value: TransactionType.debtPayment, label: Text('Abono')),
              ],
              selected: {_mode},
              onSelectionChanged: (set) {
                setState(() {
                  _mode = set.first;
                  _error = null;
                  if (_mode == TransactionType.transfer) {
                    _accountId = 'acc_davibank';
                    _toAccountId = 'acc_nequi';
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            if (_mode == TransactionType.income) ...[
              const Text(
                '¿De qué trabajo o fuente entró?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CuadraTheme.slate600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final src in activeSources)
                    ChoiceChip(
                      label: Text('${src.name} (${src.frequency.label})'),
                      selected: _incomeSourceId == src.id,
                      onSelected: (_) => setState(() => _applyIncomeSource(src)),
                    ),
                  ChoiceChip(
                    label: const Text('Otro motivo'),
                    selected: _incomeSourceId == null,
                    onSelected: (_) => setState(() => _incomeSourceId = null),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            DropdownButtonFormField<String>(
              value: _accountId,
              decoration: InputDecoration(
                labelText: _mode == TransactionType.income
                    ? 'Cuenta donde entró el dinero'
                    : 'Cuenta origen',
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final acc in ctrl.accounts)
                  DropdownMenuItem(
                    value: acc.id,
                    child: Text('${acc.name} (${formatCOP(acc.balance)})'),
                  ),
              ],
              onChanged: (val) => setState(() => _accountId = val ?? _accountId),
            ),
            const SizedBox(height: 12),

            if (_mode == TransactionType.transfer) ...[
              DropdownButtonFormField<String>(
                value: _toAccountId,
                decoration: const InputDecoration(
                  labelText: 'Cuenta destino (sin duplicar gasto)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final acc in ctrl.accounts)
                    DropdownMenuItem(value: acc.id, child: Text(acc.name)),
                ],
                onChanged: (val) => setState(() => _toAccountId = val ?? _toAccountId),
              ),
              const SizedBox(height: 12),
            ],

            if (_mode == TransactionType.debtPayment && ctrl.debts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _debtId,
                decoration: const InputDecoration(
                  labelText: 'Deuda a la que abonas',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final d in ctrl.debts)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text('${d.name} (${formatCOP(d.balance)})'),
                    ),
                ],
                onChanged: (val) => setState(() => _debtId = val),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monto (COP)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(DateFormat('dd MMM', 'es_CO').format(_selectedDate)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: _mode == TransactionType.income
                    ? 'Razón o motivo del ingreso'
                    : 'Concepto o comercio',
                border: const OutlineInputBorder(),
              ),
            ),

            if (_mode == TransactionType.expense) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final c in kExpenseCategories)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (val) => setState(() => _category = val ?? _category),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: CuadraTheme.red700, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],

            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _mode == TransactionType.income
                    ? CuadraTheme.emerald700
                    : CuadraTheme.slate900,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submit,
              child: Text(
                switch (_mode) {
                  TransactionType.income => 'Guardar ingreso',
                  TransactionType.transfer => 'Registrar traslado sin duplicar',
                  TransactionType.debtPayment => 'Registrar abono',
                  TransactionType.expense => 'Guardar gasto',
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

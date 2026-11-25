import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/finance_controller.dart';
import '../theme/cuadra_theme.dart';
import '../widgets/quick_entry_sheet.dart';
import 'budget_screen.dart';
import 'debts_screen.dart';
import 'income_screen.dart';
import 'overview_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<FinanceController>();

    final screens = [
      OverviewScreen(onJumpToTab: (i) => setState(() => _tabIndex = i)),
      const IncomeScreen(),
      const TransactionsScreen(),
      const DebtsScreen(),
      const BudgetScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cuadra',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: CuadraTheme.slate900,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => showQuickEntrySheet(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Registrar'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (ctrl.notice != null)
            MaterialBanner(
              backgroundColor: const Color(0xFFECFDF5),
              content: Text(
                ctrl.notice!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF065F46)),
              ),
              actions: [
                TextButton(
                  onPressed: ctrl.clearNotice,
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          Expanded(child: IndexedStack(index: _tabIndex, children: screens)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
            label: 'Ingresos',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movs',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Deudas',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Topes',
          ),
        ],
      ),
    );
  }
}

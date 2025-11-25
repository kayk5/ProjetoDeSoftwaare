// lib/screens/home_screen.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/screens/home_screen.dart]

import 'package:flutter/material.dart';
import 'package:ecofin/services/auth_service.dart';
import 'package:ecofin/services/goals_service.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:ecofin/services/goal_notification_service.dart';
import 'package:ecofin/models/goal_model.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'login_screen.dart';
import 'transactions_list_screen.dart';
import 'report_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'goals_list_screen.dart';
import 'accounts_list_screen.dart';
import 'alerts_screen.dart';
import 'investments_screen.dart';
import 'invoices_list_screen.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoalNotificationService _notificationService = GoalNotificationService();
  final GoalsService _goalsService = GoalsService();
  final FirestoreService _firestoreService = FirestoreService();

  // Método que exibe o pop-up customizado
  void _showGoalAchievedPopup(GoalModel goal) {
    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final bool isLimitExceeded = goal.type == 'limit';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Configura um timer para fechar após 5 segundos
        Timer(const Duration(seconds: 5), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLimitExceeded
                    ? [Colors.red.shade400, Colors.red.shade700]
                    : [Colors.green.shade400, Colors.green.shade700],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLimitExceeded ? Icons.warning_amber_rounded : Icons.celebration_outlined,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  isLimitExceeded ? 'Atenção!' : 'Parabéns!',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLimitExceeded ? 'Limite Excedido!' : 'Meta Atingida!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${formatCurrency.format(goal.currentAmount)} de ${formatCurrency.format(goal.targetAmount)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isLimitExceeded
                      ? 'Você ultrapassou o limite de gastos!'
                      : 'Você conquistou seu objetivo!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? user?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoFin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Alertas',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
            },
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // Monitor em background para verificar metas atingidas
          if (user != null) _GoalMonitor(
            userId: user.uid,
            notificationService: _notificationService,
            goalsService: _goalsService,
            firestoreService: _firestoreService,
            onGoalAchieved: _showGoalAchievedPopup,
          ),

          // Conteúdo principal da tela
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Text(
                'Bem-vindo(a),',
                style: TextStyle(fontSize: 20, color: Colors.grey[700]),
              ),
              Text(
                displayName,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              _MenuCard(
                title: 'Receitas',
                subtitle: 'Visualize e adicione suas receitas',
                icon: Icons.arrow_upward_rounded,
                iconColor: Colors.green,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsListScreen(type: 'income'))),
              ),
              const SizedBox(height: 16),

              _MenuCard(
                title: 'Despesas',
                subtitle: 'Visualize e adicione suas despesas',
                icon: Icons.arrow_downward_rounded,
                iconColor: Colors.red,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransactionsListScreen(type: 'expense'))),
              ),
              const SizedBox(height: 16),

              _MenuCard(
                title: 'Minhas Contas',
                subtitle: 'Visualize o saldo de suas contas',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: Colors.purple,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountsListScreen())),
              ),
              const SizedBox(height: 16),

              // --- NOVO CARD PARA FATURAS (RF10) ---
              _MenuCard(
                title: 'Faturas',
                subtitle: 'Gerencie suas contas a pagar',
                icon: Icons.receipt_long_rounded,
                iconColor: Colors.blueGrey,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoicesListScreen())),
              ),
              const SizedBox(height: 16),
              // --- FIM DO NOVO CARD ---

              _MenuCard(
                title: 'Investimentos',
                subtitle: 'Acompanhe seus aportes',
                icon: Icons.trending_up_rounded,
                iconColor: Colors.cyan[700]!,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvestmentsScreen())),
              ),
              const SizedBox(height: 16),

              _MenuCard(
                title: 'Metas',
                subtitle: 'Acompanhe seus objetivos financeiros',
                icon: Icons.flag_rounded,
                iconColor: Colors.orange,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsListScreen())),
              ),
              const SizedBox(height: 16),

              _MenuCard(
                title: 'Relatórios',
                subtitle: 'Analise sua saúde financeira',
                icon: Icons.bar_chart_rounded,
                iconColor: Colors.blue,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget que monitora as metas em background
class _GoalMonitor extends StatefulWidget {
  final String userId;
  final GoalNotificationService notificationService;
  final GoalsService goalsService;
  final FirestoreService firestoreService;
  final Function(GoalModel) onGoalAchieved;

  const _GoalMonitor({
    required this.userId,
    required this.notificationService,
    required this.goalsService,
    required this.firestoreService,
    required this.onGoalAchieved,
  });

  @override
  State<_GoalMonitor> createState() => _GoalMonitorState();
}

class _GoalMonitorState extends State<_GoalMonitor> {
  // Set para rastrear metas já exibidas nesta sessão (evita race condition)
  final Set<String> _shownInSession = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TransactionModel>>(
      stream: widget.firestoreService.streamUserTransactions(widget.userId),
      builder: (context, transactionSnapshot) {
        if (!transactionSnapshot.hasData) return const SizedBox.shrink();

        final transactions = transactionSnapshot.data!;

        return StreamBuilder<List<GoalModel>>(
          stream: widget.goalsService.streamUserGoals(widget.userId),
          builder: (context, goalSnapshot) {
            if (!goalSnapshot.hasData) return const SizedBox.shrink();

            final goals = goalSnapshot.data!;

            // Verifica as metas assim que os dados mudam
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkGoals(goals, transactions);
            });

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Future<void> _checkGoals(List<GoalModel> goals, List<TransactionModel> transactions) async {
    for (var goal in goals) {
      // Considera TODAS as transações da categoria até a deadline
      final relevantTransactions = transactions.where((t) {
        return t.category == goal.category &&
               (t.date.isBefore(goal.deadline) || t.date.isAtSameMomentAs(goal.deadline));
      });

      if (goal.type == 'limit') {
        goal.currentAmount = relevantTransactions
            .where((t) => t.type == 'expense')
            .fold(0.0, (sum, t) => sum + t.value);
      } else {
        goal.currentAmount = relevantTransactions
            .where((t) => t.type == 'income')
            .fold(0.0, (sum, t) => sum + t.value);
      }

      // Debug: log para verificar valores
      print('DEBUG Meta: ${goal.title} (${goal.type})');
      print('  Categoria: ${goal.category}');
      print('  Atual: ${goal.currentAmount} / Alvo: ${goal.targetAmount}');
      print('  Progresso: ${goal.progress * 100}%');
      print('  Transações relevantes: ${relevantTransactions.length}');

      // Verifica se a meta foi atingida (economia) OU excedida (limite)
      final bool isGoalAchieved = (goal.type == 'saving' && goal.progress >= 1.0) ||
                                   (goal.type == 'limit' && goal.progress >= 1.0);

      print('  Meta atingida? $isGoalAchieved');

      if (isGoalAchieved && goal.id != null) {
        // Primeiro verifica o controle local de sessão
        if (_shownInSession.contains(goal.id!)) {
          print('  Já mostrado na sessão');
          continue;
        }

        // Depois verifica o SharedPreferences
        final hasShown = await widget.notificationService.hasShownPopup(goal.id!);
        print('  Já mostrado anteriormente? $hasShown');

        if (!hasShown && mounted) {
          print('  MOSTRANDO POPUP!');
          // Marca como exibido em ambos os lugares
          _shownInSession.add(goal.id!);
          await widget.notificationService.markPopupShown(goal.id!);
          widget.onGoalAchieved(goal);
          break;
        }
      }
    }
  }
}

// Widget auxiliar _MenuCard (permanece igual)
class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withOpacity(0.1),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
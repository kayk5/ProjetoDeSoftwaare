// lib/screens/alerts_screen.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/screens/alerts_screen.dart]

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/goal_model.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:ecofin/services/goals_service.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final GoalsService _goalsService = GoalsService();
  final FirestoreService _firestoreService = FirestoreService();
  final User? user = FirebaseAuth.instance.currentUser;

  // Função que centraliza o cálculo de progresso
  List<GoalModel> _calculateProgress(List<GoalModel> goals, List<TransactionModel> allTransactions) {
    for (var goal in goals) {
      // Considera TODAS as transações da categoria até a deadline
      final relevantTransactions = allTransactions.where((t) {
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
    }
    return goals;
  }

  // --- FUNÇÃO _getAlerts MODIFICADA ---
  List<GoalModel> _getAlerts(List<GoalModel> goalsWithProgress) {
    // Pega a data de hoje (sem horas/minutos)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return goalsWithProgress.where((goal) {
      // Alerta para metas de limite de gasto (perto ou excedido)
      bool limitAlert = goal.type == 'limit' && goal.progress > 0.8;
      
      // Alerta para metas de economia atingidas
      bool savingMetAlert = goal.type == 'saving' && goal.progress >= 1.0;

      // --- NOVO ALERTA (RF-Usuário) ---
      // Verifica se hoje é o último dia
      final deadlineDay = DateTime(goal.deadline.year, goal.deadline.month, goal.deadline.day);
      final bool isLastDay = today.isAtSameMomentAs(deadlineDay);
      
      // Condição: ser uma meta de economia, ser o último dia,
      // ter pelo menos 80% e ainda não estar 100% concluída.
      bool savingLastDayNudge = goal.type == 'saving' &&
                                isLastDay &&
                                goal.progress >= 0.8 &&
                                goal.progress < 1.0;

      
      return limitAlert || savingMetAlert || savingLastDayNudge;
    }).toList();
  }
  // --- FIM DA FUNÇÃO MODIFICADA ---

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de Alertas'),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _firestoreService.streamUserTransactions(user!.uid),
        builder: (context, transactionSnapshot) {
          if (!transactionSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allTransactions = transactionSnapshot.data ?? [];

          return StreamBuilder<List<GoalModel>>(
            stream: _goalsService.streamUserGoals(user!.uid),
            builder: (context, goalSnapshot) {
              if (!goalSnapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              final allGoals = goalSnapshot.data ?? [];
              
              // 1. Calcula o progresso de todas as metas
              final goalsWithProgress = _calculateProgress(allGoals, allTransactions);
              
              // 2. Filtra apenas as que geram alertas
              final alerts = _getAlerts(goalsWithProgress);

              if (alerts.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 60),
                      SizedBox(height: 16),
                      Text('Tudo certo!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Nenhum alerta no momento.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                );
              }

              // 3. Exibe a lista de alertas
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: alerts.length,
                itemBuilder: (context, index) {
                  final alertGoal = alerts[index];
                  bool isExceeded = alertGoal.type == 'limit' && alertGoal.progress >= 1.0;
                  bool isWarning = alertGoal.type == 'limit' && alertGoal.progress > 0.8 && !isExceeded;
                  bool isGoalMet = alertGoal.type == 'saving' && alertGoal.progress >= 1.0;
                  // (O novo alerta 'savingLastDayNudge' será tratado pelo 'else')
                  
                  Color color;
                  IconData icon;
                  String title;

                  if (isExceeded) {
                    color = Colors.red.shade700;
                    icon = Icons.warning_amber_rounded;
                    title = 'Limite Excedido!';
                  } else if (isWarning) {
                    color = Colors.orange.shade700;
                    icon = Icons.info_outline;
                    title = 'Atenção ao Limite!';
                  } else if (isGoalMet) {
                    color = Colors.green;
                    icon = Icons.check_circle_outline;
                    title = 'Meta Atingida!';
                  } else {
                    // Este é o seu novo alerta de "último dia"
                    color = Colors.blue.shade700;
                    icon = Icons.run_circle_outlined;
                    title = 'Último Dia!';
                  }

                  return Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: ListTile(
                      leading: Icon(icon, color: color, size: 30),
                      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                      subtitle: Text('Meta: ${alertGoal.title} (${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(alertGoal.currentAmount)} de ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(alertGoal.targetAmount)})'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
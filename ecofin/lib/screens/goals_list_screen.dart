// lib/screens/goals_list_screen.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/screens/goals_list_screen.dart]

import 'package:ecofin/services/goals_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/goal_model.dart';
import 'package:ecofin/models/transaction_model.dart'; // Precisa das transações
import 'package:ecofin/services/firestore_service.dart'; // Precisa do serviço de transações
import 'add_goal_screen.dart';
import 'package:intl/intl.dart';
// Importado para pegar o FirebaseException

class GoalsListScreen extends StatefulWidget {
  const GoalsListScreen({super.key});

  @override
  State<GoalsListScreen> createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
  final GoalsService _goalsService = GoalsService();
  final FirestoreService _firestoreService = FirestoreService(); // Para buscar transações
  final User? user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Metas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova Meta',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddGoalScreen())),
          ),
        ],
      ),
      // Usamos StreamBuilders aninhados para uma lógica eficiente
      body: StreamBuilder<List<TransactionModel>>(
        // 1. O StreamBuilder de fora busca TODAS as transações do usuário
        stream: _firestoreService.streamUserTransactions(user!.uid),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (transactionSnapshot.hasError) {
            return const Center(child: Text('Erro ao carregar transações.'));
          }
          // Guarda a lista de transações em uma variável
          final allTransactions = transactionSnapshot.data ?? [];

          // 2. O StreamBuilder de dentro busca a lista de metas
          return StreamBuilder<List<GoalModel>>(
            stream: _goalsService.streamUserGoals(user!.uid),
            builder: (context, goalSnapshot) {
              if (goalSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.blue)));
              }
              
              // --- CÓDIGO QUE VOCÊ PEDIU ---
              // Captura o erro e exibe o link do índice no console
              if (goalSnapshot.hasError) {
                String errorMessage = 'Erro ao carregar metas.';
                if (goalSnapshot.error is FirebaseException) {
                  final e = goalSnapshot.error as FirebaseException;
                  if (e.code == 'failed-precondition') {
                    errorMessage = 'ERRO: O Firebase precisa de um índice para esta consulta.\n'
                                   'Por favor, crie o índice e reinicie o app.\n'
                                   'O link para criação está no seu CONSOLE DE DEBUG.\n'
                                   'Ele será parecido com isto:\n${e.message}';
                    
                    // Imprime o erro de forma destacada no console
                    print('================================================================');
                    print('========= ERRO DE ÍNDICE DO FIREBASE DETECTADO =========');
                    print(errorMessage);
                    print('================================================================');
                  }
                }
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage, textAlign: TextAlign.center),
                ));
              }
              // --- FIM DO CÓDIGO ---

              if (!goalSnapshot.hasData || goalSnapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma meta cadastrada.\nClique no + para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final goals = goalSnapshot.data!;

              // 3. O progresso é calculado aqui, na tela, antes de construir a lista
              for (var goal in goals) {
                // Filtra as transações que importam para esta meta
                // Considera TODAS as transações da categoria até a deadline
                final relevantTransactions = allTransactions.where((t) {
                  return t.category == goal.category &&
                         (t.date.isBefore(goal.deadline) || t.date.isAtSameMomentAs(goal.deadline));
                });

                // Calcula o valor atualizado baseado no TIPO da meta
                if (goal.type == 'limit') {
                  // Se é limite, soma as DESPESAS daquela categoria
                  goal.currentAmount = relevantTransactions
                      .where((t) => t.type == 'expense')
                      .fold(0.0, (sum, t) => sum + t.value);
                } else {
                  // Se é economia, soma as RECEITAS daquela categoria
                  goal.currentAmount = relevantTransactions
                      .where((t) => t.type == 'income')
                      .fold(0.0, (sum, t) => sum + t.value);
                }
              }

              // 4. A lista é construída com os dados já processados
              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  // Passa a meta (agora com 'currentAmount' calculado) para o Card
                  return _GoalCard(goal: goal);
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Widget de Card para exibir uma única meta (com lógica de alerta)
class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    // --- LÓGICA DE ALERTAS MODIFICADA ---
    final bool isLimit = goal.type == 'limit';
    final bool isSaving = goal.type == 'saving';

    // Lógica de verificação de data
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(goal.deadline.year, goal.deadline.month, goal.deadline.day);
    final bool isLastDay = today.isAtSameMomentAs(deadlineDay);

    Color progressColor;
    String alertMessage = '';
    IconData alertIcon = Icons.info_outline;

    if (isLimit) {
      // Meta de Limite de Gasto
      final bool isExceeded = goal.progress >= 1.0;
      final bool isNearLimit = goal.progress > 0.8 && !isExceeded;

      if (isExceeded) {
        progressColor = Colors.red.shade700;
        alertMessage = 'Limite de gasto excedido!';
        alertIcon = Icons.warning_amber_rounded;
      } else if (isNearLimit) {
        progressColor = Colors.orange.shade700;
        alertMessage = 'Atenção: Quase atingindo o limite.';
        alertIcon = Icons.info_outline;
      } else {
        progressColor = Colors.green; // Tudo ok
      }
    } 
    else if (isSaving) {
      // Meta de Economia
      final bool isMet = goal.progress >= 1.0;
      // O SEU NOVO ALERTA: Último dia E (progresso >= 80% E progresso < 100%)
      final bool isLastDayNudge = isLastDay && goal.progress >= 0.8 && !isMet;
      
      if (isMet) {
        progressColor = Colors.green;
        alertMessage = 'Parabéns, meta atingida!';
        alertIcon = Icons.check_circle_outline;
      } else if (isLastDayNudge) {
        progressColor = Colors.blue.shade700; // Um azul para "incentivo"
        alertMessage = 'Último dia! Você está com ${ (goal.progress * 100).toStringAsFixed(0) }% completo!';
        alertIcon = Icons.run_circle_outlined;
      } else {
         progressColor = Colors.green.shade400; // Cor padrão de economia
      }
    }
    else {
      // Tipo desconhecido
      progressColor = Colors.grey;
    }
    // --- FIM DA LÓGICA DE ALERTAS ---

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell( // Permite tocar no card para editar
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddGoalScreen(goal: goal)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      goal.title, // Usa o novo campo 'title'
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Até ${DateFormat('dd/MM/yy').format(goal.deadline)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  )
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isLimit ? 'Limite para "${goal.category}"' : 'Meta para "${goal.category}"',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatCurrency.format(goal.currentAmount), // O valor ATUAL (calculado)
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: progressColor),
                  ),
                  Text(
                    formatCurrency.format(goal.targetAmount), // O valor ALVO
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Barra de progresso com a cor do alerta
              LinearProgressIndicator(
                value: goal.progress, // Usa o getter 'progress'
                backgroundColor: Colors.grey[300],
                color: progressColor,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 10),
              // Exibe a mensagem de alerta se ela existir
              if (alertMessage.isNotEmpty)
                Row(
                  children: [
                    Icon(alertIcon, color: progressColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alertMessage,
                        style: TextStyle(color: progressColor, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
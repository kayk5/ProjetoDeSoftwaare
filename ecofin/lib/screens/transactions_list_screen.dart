// lib/screens/transactions_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:intl/intl.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends StatelessWidget {
  final String type; // 'income' or 'expense'

  const TransactionsListScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Usuário não autenticado')));
    final fs = FirestoreService();
    final isIncome = type == 'income';

    return Scaffold(
      appBar: AppBar(title: Text(isIncome ? 'Receitas' : 'Despesas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: isIncome ? Colors.green : Colors.red,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddTransactionScreen(type: type)),
        ),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: fs.streamUserTransactions(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
             print(snapshot.error);
             return Center(child: Text('Erro ao carregar dados. Verifique o console.'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('Nenhum lançamento encontrado.'));
          
          final allTransactions = snapshot.data!;
          final list = allTransactions.where((t) => t.type == type).toList();

          if (list.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma ${isIncome ? 'receita' : 'despesa'} registrada ainda.\nClique no botão + para adicionar.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final t = list[i];
              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  onTap: () => Navigator.of(context).push( // Ação de editar ao tocar no item
                    MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: t, type: t.type)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: CircleAvatar(
                    backgroundColor: (isIncome ? Colors.green : Colors.red).withOpacity(0.1),
                    child: Icon(
                      isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(t.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${t.category} • ${DateFormat('dd/MM/yy').format(t.date)}'),
                  
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Texto do valor
                      Text(
                        'R\$ ${t.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isIncome ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Ícone de Exclusão
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                        tooltip: 'Excluir',
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Confirmação'),
                              content: Text('Deseja realmente excluir "${t.description}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );

                          // Se o usuário confirmou e o ID é válido
                          if (confirm == true && t.id != null) {
                            try {
                              await fs.deleteTransaction(t.id!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Lançamento excluído com sucesso'))
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Erro ao excluir: ${e.toString()}'))
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
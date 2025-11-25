// lib/screens/investments_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/bank_account_model.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:ecofin/services/bank_account_service.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:intl/intl.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado.')));
    }

    final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final firestoreService = FirestoreService();
    final accountService = BankAccountService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Investimentos'),
      ),
      body: StreamBuilder<List<TransactionModel>>(
        // 1. Busca todas as transações do usuário
        stream: firestoreService.streamUserTransactions(user.uid),
        builder: (context, transactionSnapshot) {
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (transactionSnapshot.hasError) {
            return const Center(child: Text('Erro ao carregar transações.'));
          }

          final allTransactions = transactionSnapshot.data ?? [];
          
          // 2. Filtra apenas as transações que são investimentos
          final investmentTransactions = allTransactions.where((t) {
            // Assumindo que 'Investimentos' é uma categoria de despesa
            return t.category == 'Investimentos' && t.type == 'expense';
          }).toList();

          // 3. Calcula o total geral investido
          final totalInvested = investmentTransactions.fold(
              0.0, (sum, t) => sum + t.value);

          // 4. Busca as contas para agrupar
          return StreamBuilder<List<BankAccountModel>>(
            stream: accountService.streamUserAccounts(user.uid),
            builder: (context, accountSnapshot) {
              if (accountSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (accountSnapshot.hasError) {
                return const Center(child: Text('Erro ao carregar contas.'));
              }

              final accounts = accountSnapshot.data ?? [];
              
              // Mapa para armazenar o total por conta
              Map<String, double> totalsByAccount = {};
              for (var account in accounts) {
                final accountInvestments = investmentTransactions
                    .where((t) => t.accountId == account.id)
                    .fold(0.0, (sum, t) => sum + t.value);
                
                if (accountInvestments > 0) {
                  totalsByAccount[account.accountName] = accountInvestments;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Card 1: Total Geral
                  Card(
                    elevation: 4.0,
                    color: Colors.green[800],
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Investido',
                            style: TextStyle(fontSize: 18, color: Colors.white70),
                          ),
                          Text(
                            formatCurrency.format(totalInvested),
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    'Investimentos por Conta',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  
                  if (totalsByAccount.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('Nenhum investimento lançado nas suas contas.')),
                    )
                  else
                    // Lista de Contas com Investimentos
                    ...totalsByAccount.entries.map((entry) {
                      return Card(
                        elevation: 1.0,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          leading: Icon(Icons.trending_up, color: Colors.green[700]),
                          title: Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            formatCurrency.format(entry.value),
                            style: TextStyle(fontSize: 16, color: Colors.green[800]),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
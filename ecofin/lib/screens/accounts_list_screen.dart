import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/bank_account_model.dart';
import 'package:ecofin/services/bank_account_service.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:intl/intl.dart';

class AccountsListScreen extends StatefulWidget {
  const AccountsListScreen({super.key});

  @override
  State<AccountsListScreen> createState() => _AccountsListScreenState();
}

class _AccountsListScreenState extends State<AccountsListScreen> {
  final BankAccountService _accountService = BankAccountService();
  final FirestoreService _firestoreService = FirestoreService(); // <-- NOVO SERVIÇO
  final User? user = FirebaseAuth.instance.currentUser;
  final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // Função para mostrar popup de sucesso
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Auto-fecha após 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
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
                colors: [Colors.green.shade400, Colors.green.shade700],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
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

  // Função para mostrar o diálogo (modal) de adicionar/editar conta
  // (Esta função permanece idêntica à da Fase 1, não precisa mexer)
  void _showAccountDialog({BankAccountModel? account}) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: account?.accountName ?? '');
    final balanceController = TextEditingController(
        text: account?.initialBalance.toStringAsFixed(2).replaceAll('.', ',') ?? '0,00');
    bool isEditing = account != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Conta' : 'Nova Conta'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Conta (ex: Carteira, NuConta)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Dê um nome' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: balanceController,
                  decoration: const InputDecoration(
                    labelText: 'Saldo Inicial (R\$)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v == null ||
                          double.tryParse(v.replaceAll(',', '.')) == null
                      ? 'Valor inválido'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && user != null) {
                  final newAccount = BankAccountModel(
                    id: account?.id,
                    userId: user!.uid,
                    accountName: nameController.text.trim(),
                    initialBalance:
                        double.parse(balanceController.text.replaceAll(',', '.')),
                  );

                  try {
                    if (isEditing) {
                      await _accountService.updateAccount(newAccount);
                      Navigator.of(context).pop();
                      // Aguarda um frame para o dialog fechar antes de mostrar o popup
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (mounted) {
                        _showSuccessDialog('Conta Atualizada!', 'A conta foi atualizada com sucesso.');
                      }
                    } else {
                      await _accountService.addAccount(newAccount);
                      Navigator.of(context).pop();
                      // Aguarda um frame para o dialog fechar antes de mostrar o popup
                      await Future.delayed(const Duration(milliseconds: 100));
                      if (mounted) {
                        _showSuccessDialog('Conta Cadastrada!', 'A conta "${newAccount.accountName}" foi cadastrada com sucesso.');
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
                    }
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Contas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        tooltip: 'Nova Conta',
        child: const Icon(Icons.add),
      ),
      // --- BODY MODIFICADO ---
      // Envolvemos tudo em um StreamBuilder que busca TODAS as transações
      body: StreamBuilder<List<TransactionModel>>(
        stream: _firestoreService.streamUserTransactions(user!.uid),
        builder: (context, transactionSnapshot) {
          // Enquanto as transações carregam, mostramos um loading
          if (transactionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (transactionSnapshot.hasError) {
             return const Center(child: Text('Erro ao carregar transações.'));
          }

          final allTransactions = transactionSnapshot.data ?? [];

          // Agora, dentro, buscamos as contas
          return StreamBuilder<List<BankAccountModel>>(
            stream: _accountService.streamUserAccounts(user!.uid),
            builder: (context, accountSnapshot) {
              if (accountSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (accountSnapshot.hasError) {
                return const Center(child: Text('Erro ao carregar contas.'));
              }
              if (!accountSnapshot.hasData || accountSnapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma conta cadastrada.\nClique no + para começar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final accounts = accountSnapshot.data!;
              
              // --- CÁLCULO DO SALDO TOTAL GERAL ---
              double overallBalance = 0;

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: accounts.length + 1, // +1 para o Card de Saldo Total
                itemBuilder: (context, index) {

                  // --- ITEM 0: CARD DE SALDO TOTAL ---
                  if (index == 0) {
                    // Calcula o saldo geral somando tudo
                    double initialBalances = accounts.fold(0.0, (sum, acc) => sum + acc.initialBalance);
                    double allIncomes = allTransactions.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.value);
                    double allExpenses = allTransactions.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.value);
                    overallBalance = initialBalances + allIncomes - allExpenses;

                    return Card(
                      elevation: 4.0,
                      color: Colors.blue[800],
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saldo Total Consolidado',
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                            ),
                            Text(
                              formatCurrency.format(overallBalance),
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // --- ITENS SEGUINTES: CARDS DAS CONTAS ---
                  final account = accounts[index - 1]; // -1 por causa do card de total

                  // --- LÓGICA DE CÁLCULO DE SALDO POR CONTA ---
                  final accountTransactions = allTransactions
                      .where((t) => t.accountId == account.id)
                      .toList();
                  
                  final totalIncomes = accountTransactions
                      .where((t) => t.type == 'income')
                      .fold(0.0, (sum, t) => sum + t.value);
                  
                  final totalExpenses = accountTransactions
                      .where((t) => t.type == 'expense')
                      .fold(0.0, (sum, t) => sum + t.value);
                  
                  final currentBalance = account.initialBalance + totalIncomes - totalExpenses;
                  // --- FIM DA LÓGICA ---

                  return Card(
                    elevation: 2.0,
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: ListTile(
                      leading: Icon(Icons.account_balance_wallet_outlined, size: 40, color: Colors.purple[700]),
                      title: Text(account.accountName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      // Exibe o SALDO ATUAL calculado
                      subtitle: Text(
                        formatCurrency.format(currentBalance),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: currentBalance >= 0 ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.blueGrey[600]),
                            tooltip: 'Editar',
                            onPressed: () =>
                                _showAccountDialog(account: account),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                            tooltip: 'Excluir',
                            onPressed: () async {
                              // Adicionar confirmação
                              await _accountService.deleteAccount(account.id!);
                            },
                          ),
                        ],
                      ),
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
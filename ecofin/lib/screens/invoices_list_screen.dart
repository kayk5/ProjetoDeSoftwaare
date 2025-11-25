// lib/screens/invoices_list_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/invoice_model.dart';
import 'package:ecofin/models/bank_account_model.dart';
import 'package:ecofin/services/invoice_service.dart';
import 'package:ecofin/services/bank_account_service.dart';
import 'package:ecofin/screens/add_invoice_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final BankAccountService _accountService = BankAccountService();
  final User? user = FirebaseAuth.instance.currentUser;
  final formatCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  // Diálogo para confirmar o pagamento (seu código original)
  Future<void> _showPayDialog(InvoiceModel invoice, List<BankAccountModel> accounts) async {
    String? paymentAccountId = accounts.any((a) => a.id == invoice.accountId) 
        ? invoice.accountId 
        : (accounts.isNotEmpty ? accounts.first.id : null);
    
    if (paymentAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não tem contas cadastradas para pagar.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fatura: ${invoice.description}'),
            Text('Valor: ${formatCurrency.format(invoice.amount)}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: paymentAccountId,
              items: accounts.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.accountName))).toList(),
              onChanged: (val) => paymentAccountId = val,
              decoration: const InputDecoration(labelText: 'Pagar com a conta:'),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                // Chama o método payInvoice do seu serviço
                await _invoiceService.payInvoice(invoice, paymentAccountId!);
                Navigator.of(ctx).pop(true);
              } catch (e) {
                Navigator.of(ctx).pop(false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao pagar: $e')));
              }
            }, 
            child: const Text('Pagar Agora')
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura paga e despesa lançada!')));
    }
  }

  // --- NOVA FUNÇÃO DE EXCLUSÃO (ADICIONADA) ---
  Future<void> _deleteInvoice(InvoiceModel invoice) async {
    // 1. Confirmação
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja realmente excluir a fatura "${invoice.description}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // 2. Ação de Excluir
    if (confirm == true && invoice.id != null) {
      try {
        // Chama o método deleteInvoice do seu serviço
        await _invoiceService.deleteInvoice(invoice.id!); 
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura excluída com sucesso')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: ${e.toString()}')));
        }
      }
    }
  }
  // --- FIM DA NOVA FUNÇÃO ---


  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Usuário não autenticado.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Faturas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddInvoiceScreen())),
        tooltip: 'Nova Fatura',
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<BankAccountModel>>(
        stream: _accountService.streamUserAccounts(user!.uid),
        builder: (context, accountSnapshot) {
          if (!accountSnapshot.hasData && accountSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = accountSnapshot.data ?? [];

          return StreamBuilder<List<InvoiceModel>>(
            // Usando o método streamUserInvoices (sem 'ByStatus') do seu código
            stream: _invoiceService.streamUserInvoices(user!.uid),
            builder: (context, invoiceSnapshot) {
              if (invoiceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // --- CAPTURA DE ERRO DO ÍNDICE --- (Mantida)
              if (invoiceSnapshot.hasError) {
                String errorMessage = 'Erro ao carregar faturas.';
                if (invoiceSnapshot.error is FirebaseException) {
                  final e = invoiceSnapshot.error as FirebaseException;
                  if (e.code == 'failed-precondition') {
                    errorMessage = 'ERRO: O Firebase precisa de um índice para esta consulta.\n'
                                   'Por favor, crie o índice e reinicie o app.\n'
                                   'O link para criação está no seu CONSOLE DE DEBUG.\n'
                                   'Ele será parecido com isto:\n${e.message}';
                    print('================================================================');
                    print('========= ERRO DE ÍNDICE DO FIREBASE DETECTADO (Faturas) =========');
                    print('COLE O LINK ABAIXO NO SEU NAVEGADOR PARA CRIAR O ÍNDICE:');
                    print(e.message); // O link estará aqui
                    print('================================================================');
                  }
                }
                return Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage, textAlign: TextAlign.center),
                ));
              }
              // --- FIM DA CAPTURA DE ERRO ---

              if (!invoiceSnapshot.hasData || invoiceSnapshot.data!.isEmpty) {
                return const Center(child: Text('Nenhuma fatura cadastrada.'));
              }

              final allInvoices = invoiceSnapshot.data!;
              final pendingInvoices = allInvoices.where((inv) => inv.status == 'pending').toList();
              final paidInvoices = allInvoices.where((inv) => inv.status == 'paid').toList();

              return ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  _buildInvoiceList('Pendentes (${pendingInvoices.length})', pendingInvoices, accounts, true),
                  const SizedBox(height: 16),
                  _buildInvoiceList('Pagas (${paidInvoices.length})', paidInvoices, accounts, false),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // Widget auxiliar para construir as listas
  Widget _buildInvoiceList(String title, List<InvoiceModel> invoices, List<BankAccountModel> accounts, bool isPending) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); // Ignora horas/minutos
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (invoices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: Text('Nenhuma fatura ${isPending ? 'pendente' : 'paga'}.', style: TextStyle(color: Colors.grey))),
          ),
        ...invoices.map((invoice) {
          final dueDate = DateTime(invoice.dueDate.year, invoice.dueDate.month, invoice.dueDate.day); // Ignora horas/minutos
          final bool isOverdue = isPending && dueDate.isBefore(today);
          final color = isOverdue ? Colors.red.shade700 : (isPending ? Colors.orange.shade700 : Colors.green.shade700);
          final daysLeft = dueDate.difference(today).inDays;
          
          String subtitle;
          if (isPending) {
            if (isOverdue) {
              subtitle = 'Venceu há ${daysLeft.abs()} dia(s)';
            } else if (daysLeft == 0) {
              subtitle = 'Vence hoje!';
            } else {
              subtitle = 'Vence em $daysLeft dia(s)';
            }
          } else {
            subtitle = 'Paga (Ref. Venc. ${DateFormat('dd/MM/yy').format(invoice.dueDate)})';
          }

          return Card(
            elevation: 1.0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isOverdue ? Colors.red.shade200 : Colors.transparent, width: 1.5)
            ),
            child: ListTile(
              leading: Icon(Icons.receipt_long_rounded, color: color, size: 40),
              title: Text(invoice.description, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
              
              // --- TRAILING MODIFICADO PARA INCLUIR EDITAR E EXCLUIR ---
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mostra o valor se estiver paga
                  if (!isPending)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        formatCurrency.format(invoice.amount), 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                    ),
                  
                  // Mostra o botão "Pagar" se estiver pendente
                  if (isPending)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      tooltip: 'Pagar Fatura',
                      onPressed: () => _showPayDialog(invoice, accounts),
                    ),
                  
                  // Botão Editar (funciona em ambas as abas)
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: Colors.blueGrey[600], size: 22),
                    tooltip: 'Editar Fatura',
                    onPressed: () {
                      // Navega para a tela de edição, passando a fatura
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AddInvoiceScreen(invoice: invoice)));
                    },
                  ),

                  // Botão Excluir (funciona em ambas as abas)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[700], size: 22),
                    tooltip: 'Excluir Fatura',
                    onPressed: () => _deleteInvoice(invoice), // Chama a nova função
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
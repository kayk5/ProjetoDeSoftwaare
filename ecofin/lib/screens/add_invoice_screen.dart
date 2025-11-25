// lib/screens/add_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/models/bank_account_model.dart';
import 'package:ecofin/models/invoice_model.dart';
import 'package:ecofin/services/bank_account_service.dart';
import 'package:ecofin/services/invoice_service.dart';
import 'package:intl/intl.dart';

class AddInvoiceScreen extends StatefulWidget {
  final InvoiceModel? invoice; // Para modo de edição

  const AddInvoiceScreen({super.key, this.invoice});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _dueDate = DateTime.now();
  String? _selectedAccountId;
  bool _isLoading = false;

  final InvoiceService _invoiceService = InvoiceService();
  final BankAccountService _accountService = BankAccountService();

  @override
  void initState() {
    super.initState();
    if (widget.invoice != null) {
      final inv = widget.invoice!;
      _descController.text = inv.description;
      _amountController.text = inv.amount.toStringAsFixed(2).replaceAll('.', ',');
      _dueDate = inv.dueDate;
      _selectedAccountId = inv.accountId;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
      return;
    }
     if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma conta.')));
      return;
    }

    setState(() => _isLoading = true);

    final invoiceToSave = InvoiceModel(
      id: widget.invoice?.id,
      userId: user.uid,
      description: _descController.text.trim(),
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      dueDate: _dueDate,
      accountId: _selectedAccountId!,
      status: widget.invoice?.status ?? 'pending', // Mantém o status se estiver editando
    );

    try {
      if (widget.invoice == null) {
        await _invoiceService.addInvoice(invoiceToSave);
      } else {
        await _invoiceService.updateInvoice(invoiceToSave);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura salva com sucesso!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar fatura: $e')));
       }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(widget.invoice == null ? 'Nova Fatura' : 'Editar Fatura')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Descrição (ex: Fatura NuBank, Aluguel)'),
                  validator: (v) => v!.trim().isEmpty ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o valor';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (user != null)
                  StreamBuilder<List<BankAccountModel>>(
                    stream: _accountService.streamUserAccounts(user.uid),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final accounts = snapshot.data ?? [];
                      if (_selectedAccountId != null && !accounts.any((a) => a.id == _selectedAccountId)) {
                         _selectedAccountId = null;
                      }
                      return DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        hint: const Text('Conta Padrão para Pagamento'),
                        items: accounts.map((account) => DropdownMenuItem(
                          value: account.id,
                          child: Text(account.accountName),
                        )).toList(),
                        onChanged: (v) => setState(() => _selectedAccountId = v),
                        decoration: const InputDecoration(labelText: 'Conta Padrão', border: OutlineInputBorder()),
                         validator: (v) => v == null ? 'Selecione uma conta' : null,
                      );
                    },
                  ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.grey.shade400)
                  ),
                  title: const Text('  Data de Vencimento'),
                  subtitle: Text('  ${DateFormat('dd/MM/yyyy').format(_dueDate)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _saveInvoice,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Salvar Fatura'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// lib/screens/add_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
// --- NOVOS IMPORTS ---
import 'package:ecofin/models/bank_account_model.dart';
import 'package:ecofin/services/bank_account_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? transaction;
  final String type;

  const AddTransactionScreen({super.key, this.transaction, required this.type});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _valueController = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'Outros';
  final FirestoreService _fs = FirestoreService();
  bool _isLoading = false;

  // --- NOVAS VARIÁVEIS DE ESTADO ---
  final BankAccountService _accountService = BankAccountService();
  String? _selectedAccountId; // Armazena o ID da conta selecionada
  List<BankAccountModel> _accounts = []; // Armazena a lista de contas

  final List<String> _categories = const [
    'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Salário', 'Investimentos', 'Outros'
  ];

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _descController.text = tx.description;
      _valueController.text = tx.value.toStringAsFixed(2).replaceAll('.', ',');
      _date = tx.date;
      _category = tx.category;
      _selectedAccountId = tx.accountId; // Pré-seleciona a conta no modo de edição
    } else {
      _category = (widget.type == 'income' && _categories.contains('Salário')) ? 'Salário' : 'Outros';
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // --- VALIDAÇÃO DA CONTA ---
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione uma conta.')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado')));
      return;
    }

    setState(() => _isLoading = true);

    final tx = TransactionModel(
      id: widget.transaction?.id,
      userId: user.uid,
      accountId: _selectedAccountId!, // <-- PASSA A CONTA SELECIONADA
      type: widget.type,
      description: _descController.text.trim(),
      value: double.parse(_valueController.text.replaceAll(',', '.')),
      date: _date,
      category: _category,
    );

    try {
      if (widget.transaction == null) {
        await _fs.addTransaction(tx);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transação adicionada')));
      } else {
        await _fs.updateTransaction(tx);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transação atualizada')));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.transaction == null ? 'Nova ${widget.type == 'income' ? 'Receita' : 'Despesa'}' : 'Editar';
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  validator: (v) => v == null || v.isEmpty ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                     if (v == null || v.trim().isEmpty) return 'Informe o valor';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                    return null;
                  }
                ),
                const SizedBox(height: 16),

                // --- NOVO WIDGET: SELETOR DE CONTA ---
                if (user != null)
                  StreamBuilder<List<BankAccountModel>>(
                    stream: _accountService.streamUserAccounts(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                        return const Card(
                          child: ListTile(
                            leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            title: Text("Nenhuma conta encontrada"),
                            subtitle: Text("Vá para 'Minhas Contas' e crie uma primeiro."),
                          ),
                        );
                      }
                      
                      _accounts = snapshot.data!;
                      
                      // Garante que o ID selecionado ainda existe na lista
                      if (_selectedAccountId != null && !_accounts.any((a) => a.id == _selectedAccountId)) {
                        _selectedAccountId = null;
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        hint: const Text('Selecione uma Conta'),
                        items: _accounts.map((account) {
                          return DropdownMenuItem<String>(
                            value: account.id, // O valor é o ID
                            child: Text(account.accountName),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedAccountId = v),
                        decoration: const InputDecoration(
                          labelText: 'Conta',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null ? 'Selecione uma conta' : null,
                      );
                    },
                  ),
                const SizedBox(height: 16),

                // Seletor de Data
                Card(
                  elevation: 1,
                  child: ListTile(
                    title: const Text('Data'),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Seletor de Categoria
                DropdownButtonFormField<String>(
                  value: _category,
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'Outros'),
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Salvar'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
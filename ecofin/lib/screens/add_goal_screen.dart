// lib/screens/add_goal_screen.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/screens/add_goal_screen.dart]

import 'package:ecofin/services/goals_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ecofin/models/goal_model.dart';
import 'package:intl/intl.dart';

class AddGoalScreen extends StatefulWidget {
  final GoalModel? goal; // Recebe uma meta para edição
  const AddGoalScreen({super.key, this.goal});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controladores atualizados para os novos nomes de campo
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _deadline = DateTime.now();
  bool _isLoading = false;

  // --- NOVOS CAMPOS ---
  String _selectedCategory = 'Alimentação'; // Categoria a monitorar
  String _selectedType = 'limit'; // Tipo da meta

  final GoalsService _goalsService = GoalsService();

  // Lista de categorias (deve ser a mesma da tela de transações)
  final List<String> _categories = const [
    'Alimentação', 'Transporte', 'Moradia', 'Lazer', 'Salário', 'Investimentos', 'Outros'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.goal != null) {
      final g = widget.goal!;
      _titleController.text = g.title;
      _amountController.text = g.targetAmount.toStringAsFixed(2).replaceAll('.', ',');
      _deadline = g.deadline;
      _selectedCategory = g.category;
      _selectedType = g.type;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _deadline) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuário não autenticado.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Verifica se já existe uma meta com a mesma categoria (apenas para novas metas)
      if (widget.goal == null) {
        final existingGoals = await _goalsService.streamUserGoals(user.uid).first;
        final hasDuplicate = existingGoals.any((g) => g.category == _selectedCategory);

        if (hasDuplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Já existe uma meta para a categoria "$_selectedCategory"'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Salva o novo modelo com os campos corretos
      final goalToSave = GoalModel(
        id: widget.goal?.id,
        userId: user.uid,
        title: _titleController.text.trim(),
        targetAmount: double.parse(_amountController.text.replaceAll(',', '.')),
        deadline: _deadline,
        category: _selectedCategory, // <-- NOVO
        type: _selectedType,       // <-- NOVO
      );

      if (widget.goal == null) {
        await _goalsService.addGoal(goalToSave);
      } else {
        // Ao editar, verifica se mudou a categoria e se a nova categoria já existe
        if (widget.goal!.category != _selectedCategory) {
          final existingGoals = await _goalsService.streamUserGoals(user.uid).first;
          final hasDuplicate = existingGoals.any((g) => g.category == _selectedCategory && g.id != widget.goal!.id);

          if (hasDuplicate) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Já existe uma meta para a categoria "$_selectedCategory"'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }
        await _goalsService.updateGoal(goalToSave);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meta salva com sucesso!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar meta: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.goal == null ? 'Nova Meta' : 'Editar Meta')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Título da Meta (ex: Economizar para Viagem)'),
                  validator: (v) => v!.trim().isEmpty ? 'Dê um título para sua meta' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Valor Alvo (R\$)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                   validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o valor';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // --- NOVO DROPDOWN PARA TIPO ---
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'limit', child: Text('Limite de Gasto (Ex: Gastar no máx. R\$ 500)')),
                    DropdownMenuItem(value: 'saving', child: Text('Meta de Economia (Ex: Juntar R\$ 500)')),
                  ],
                  onChanged: (v) => setState(() => _selectedType = v ?? 'limit'),
                  decoration: const InputDecoration(labelText: 'Tipo de Meta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                 // --- NOVO DROPDOWN PARA CATEGORIA ---
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'Outros'),
                  decoration: const InputDecoration(labelText: 'Categoria a Monitorar', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Colors.grey.shade400)
                  ),
                  title: const Text('  Prazo Final'),
                  subtitle: Text('  ${DateFormat('dd/MM/yyyy').format(_deadline)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _saveGoal,
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
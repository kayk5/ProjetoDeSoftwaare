import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ecofin/services/firestore_service.dart';
import 'package:ecofin/models/transaction_model.dart';

enum ReportPeriod { monthly, weekly, custom }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  ReportPeriod _period = ReportPeriod.monthly;
  DateTimeRange? _customRange;
  final FirestoreService _fs = FirestoreService();
  bool _loading = false;
  List<TransactionModel> _results = [];
  StreamSubscription<List<TransactionModel>>? _subscription;

  DateTimeRange _currentMonthRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange _currentWeekRange() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(start: start, end: end);
  }

  Future<void> _runReport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
  setState(() => _loading = true);
    DateTime start, end;
    if (_period == ReportPeriod.monthly) {
      final r = _currentMonthRange();
      start = r.start;
      end = r.end;
    } else if (_period == ReportPeriod.weekly) {
      final r = _currentWeekRange();
      start = r.start;
      end = r.end;
    } else {
      if (_customRange == null) return;
      start = _customRange!.start;
      end = _customRange!.end;
    }
    // cancel previous subscription
    await _subscription?.cancel();
    // subscribe to all transactions for user and filter locally by date range
    _subscription = _fs.streamUserTransactions(user.uid).listen((all) {
      final filtered = all.where((t) => t.date.isAfter(start.subtract(const Duration(milliseconds: 1))) && t.date.isBefore(end.add(const Duration(milliseconds: 1)))).toList();
      setState(() {
        _results = filtered;
        _loading = false;
      });
    }, onError: (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar relatório: ${e.toString()}')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final incomes = _results.where((r) => r.type == 'income').fold<double>(0, (p, e) => p + e.value);
    final expenses = _results.where((r) => r.type == 'expense').fold<double>(0, (p, e) => p + e.value);
    final balance = incomes - expenses;
    final grouped = <String, double>{};
    for (var r in _results) {
      grouped[r.category] = (grouped[r.category] ?? 0) + r.value;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Relatório')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<ReportPeriod>(
                    value: _period,
                    items: const [
                      DropdownMenuItem(value: ReportPeriod.monthly, child: Text('Mensal')),
                      DropdownMenuItem(value: ReportPeriod.weekly, child: Text('Semanal')),
                      DropdownMenuItem(value: ReportPeriod.custom, child: Text('Personalizado')),
                    ],
                    onChanged: (v) => setState(() => _period = v!),
                  ),
                ),
                ElevatedButton(onPressed: () async {
                  if (_period == ReportPeriod.custom) {
                    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2100), initialDateRange: _customRange);
                    if (picked != null) setState(() => _customRange = picked);
                  }
                }, child: const Text('Selecionar')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _runReport, child: const Text('Gerar')),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading) ...[
              Card(
                child: ListTile(
                  title: const Text('Receitas'),
                  trailing: Text(incomes.toStringAsFixed(2)),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Despesas'),
                  trailing: Text(expenses.toStringAsFixed(2)),
                ),
              ),
              Card(
                child: ListTile(
                  title: const Text('Saldo'),
                  trailing: Text(balance.toStringAsFixed(2)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Por categoria', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView(
                  children: grouped.entries.map((e) => ListTile(title: Text(e.key), trailing: Text(e.value.toStringAsFixed(2)))).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

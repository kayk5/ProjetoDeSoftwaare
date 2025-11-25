// lib/models/transaction_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String? id;
  final String userId;
  final String accountId; // <-- CAMPO ADICIONADO
  final String type;
  final String description;
  final double value;
  final DateTime date;
  final String category;

  TransactionModel({
    this.id,
    required this.userId,
    required this.accountId, // <-- ADICIONADO AO CONSTRUTOR
    required this.type,
    required this.description,
    required this.value,
    required this.date,
    required this.category,
  });

  // Método para converter para Map (usado em add e update)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountId': accountId, // <-- ADICIONADO AO MAP
      'type': type,
      'description': description,
      'value': value,
      'date': Timestamp.fromDate(date),
      'category': category,
    };
  }

  // Factory constructor para criar a partir de um DocumentSnapshot (usado na leitura)
  factory TransactionModel.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      accountId: data['accountId'] ?? '', // <-- ADICIONADO AO FACTORY (importante para dados antigos)
      type: data['type'] ?? '',
      description: data['description'] ?? '',
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] ?? 'Outros',
    );
  }
}
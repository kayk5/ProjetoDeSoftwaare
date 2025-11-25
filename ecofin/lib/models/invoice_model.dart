// lib/models/invoice_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceModel {
  final String? id;
  final String userId;
  final String accountId; // Conta de débito padrão
  final String description; // Ex: "Fatura Nubank", "Aluguel"
  final double amount;
  final DateTime dueDate; // Data de Vencimento
  final String status; // 'pending' (pendente) ou 'paid' (paga)
  final String? relatedTransactionId; // ID da transação de despesa gerada

  InvoiceModel({
    this.id,
    required this.userId,
    required this.accountId,
    required this.description,
    required this.amount,
    required this.dueDate,
    this.status = 'pending',
    this.relatedTransactionId,
  });

  // Método 'copyWith' para facilitar a atualização do status
  InvoiceModel copyWith({
    String? status,
    String? relatedTransactionId,
  }) {
    return InvoiceModel(
      id: id,
      userId: userId,
      accountId: accountId,
      description: description,
      amount: amount,
      dueDate: dueDate,
      status: status ?? this.status,
      relatedTransactionId: relatedTransactionId ?? this.relatedTransactionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountId': accountId,
      'description': description,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'relatedTransactionId': relatedTransactionId,
    };
  }

  factory InvoiceModel.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InvoiceModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      accountId: data['accountId'] ?? '',
      description: data['description'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      relatedTransactionId: data['relatedTransactionId'],
    );
  }
}
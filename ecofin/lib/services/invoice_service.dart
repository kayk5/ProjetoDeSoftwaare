// lib/services/invoice_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecofin/models/invoice_model.dart';
import 'package:ecofin/models/transaction_model.dart';
import 'package:ecofin/services/firestore_service.dart'; // Importa o serviço de transações

class InvoiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'invoices'; // Nova coleção

  // Adiciona uma nova fatura
  Future<void> addInvoice(InvoiceModel invoice) async {
    await _db.collection(_collectionName).add(invoice.toMap());
  }

  // Atualiza uma fatura (usado para editar ou marcar como paga manualmente)
  Future<void> updateInvoice(InvoiceModel invoice) async {
    if (invoice.id == null) throw ArgumentError('ID da fatura não pode ser nulo');
    await _db.collection(_collectionName).doc(invoice.id).update(invoice.toMap());
  }

  // Exclui uma fatura
  Future<void> deleteInvoice(String id) async {
    await _db.collection(_collectionName).doc(id).delete();
  }

  // Busca todas as faturas do usuário, ordenadas por vencimento
  Stream<List<InvoiceModel>> streamUserInvoices(String userId) {
    return _db
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .orderBy('dueDate', descending: false) // <--- VAI EXIGIR ÍNDICE
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InvoiceModel.fromDoc(doc)).toList());
  }

  // Método principal: Paga uma fatura
  // 1. Cria a transação de despesa
  // 2. Atualiza a fatura como "paga" e salva o ID da transação
  Future<void> payInvoice(InvoiceModel invoice, String paymentAccountId) async {
    if (invoice.status == 'paid') {
      throw Exception('Esta fatura já foi paga.');
    }

    final firestoreService = FirestoreService();

    // 1. Cria a transação de despesa
    final newTransaction = TransactionModel(
      userId: invoice.userId,
      accountId: paymentAccountId, // A conta da qual o dinheiro saiu
      type: 'expense', // Fatura é sempre uma despesa
      description: invoice.description, // "Fatura Nubank"
      value: invoice.amount,
      date: DateTime.now(), // Data do pagamento é hoje
      category: 'Faturas', // (Ou outra categoria que você queira)
    );

    try {
      // Adiciona a transação
      final transactionId = await firestoreService.addTransaction(newTransaction);
      
      // 2. Atualiza a fatura
      final updatedInvoice = invoice.copyWith(
        status: 'paid',
        relatedTransactionId: transactionId,
      );
      await updateInvoice(updatedInvoice);

    } catch (e) {
      // Se falhar, relança o erro para a UI
      rethrow;
    }
  }
}
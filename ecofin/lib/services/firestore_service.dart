import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecofin/models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'transactions';

  Future<String> addTransaction(TransactionModel tx) async {
    final docRef = await _db.collection(collection).add(tx.toMap());
    return docRef.id;
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    if (tx.id == null) throw ArgumentError('Transaction id is null');
    await _db.collection(collection).doc(tx.id).update(tx.toMap());
  }

  Future<void> deleteTransaction(String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  Stream<List<TransactionModel>> streamUserTransactions(String userId) {
  return _db
    .collection(collection)
    .where('userId', isEqualTo: userId)
    .orderBy('date', descending: true)
  .snapshots()
    .map((snap) => snap.docs.map((d) => TransactionModel.fromDoc(d)).toList());
  }

  Stream<List<TransactionModel>> streamUserTransactionsByType(String userId, String type) {
    return _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .orderBy('date', descending: true)
      .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromDoc(d)).toList());
  }

  // Expose the raw QuerySnapshot stream for debugging/metadata
  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserTransactionsByTypeSnapshots(String userId, String type) {
    return _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: type)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<List<TransactionModel>> queryTransactionsByPeriod(
      String userId, DateTime start, DateTime end) async {
    final snap = await _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => TransactionModel.fromDoc(d)).toList();
  }

  Stream<List<TransactionModel>> streamTransactionsByPeriod(
      String userId, DateTime start, DateTime end) {
    return _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
      .snapshots()
        .map((snap) => snap.docs.map((d) => TransactionModel.fromDoc(d)).toList());
  }
}

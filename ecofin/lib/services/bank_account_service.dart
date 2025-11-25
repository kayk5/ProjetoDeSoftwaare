import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecofin/models/bank_account_model.dart';

class BankAccountService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionName = 'bank_accounts'; // Nome da coleção no Firebase

  // Adiciona uma nova conta
  Future<void> addAccount(BankAccountModel account) async {
    await _db.collection(_collectionName).add(account.toMap());
  }

  // Edita uma conta existente
  Future<void> updateAccount(BankAccountModel account) async {
    if (account.id == null) {
      throw ArgumentError("ID da conta não pode ser nulo para atualizar");
    }
    await _db.collection(_collectionName).doc(account.id).update(account.toMap());
  }

  // Exclui uma conta
  Future<void> deleteAccount(String accountId) async {
    await _db.collection(_collectionName).doc(accountId).delete();
  }

  // Busca todas as contas de um usuário em tempo real
  Stream<List<BankAccountModel>> streamUserAccounts(String userId) {
    return _db
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BankAccountModel.fromDoc(doc))
            .toList());
  }
}
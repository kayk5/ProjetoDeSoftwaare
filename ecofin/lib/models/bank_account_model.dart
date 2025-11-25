import 'package:cloud_firestore/cloud_firestore.dart';

class BankAccountModel {
  final String? id;
  final String userId;
  final String accountName;
  final double initialBalance;
  final String iconName; // Para mostrar um ícone (ex: 'account_balance', 'credit_card')

  BankAccountModel({
    this.id,
    required this.userId,
    required this.accountName,
    required this.initialBalance,
    this.iconName = 'account_balance', // Ícone padrão
  });

  // Converte o objeto Dart para um Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountName': accountName,
      'initialBalance': initialBalance,
      'iconName': iconName,
    };
  }

  // Cria um objeto BankAccountModel a partir de um documento lido do Firestore
  factory BankAccountModel.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BankAccountModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      accountName: data['accountName'] ?? 'Conta desconhecida',
      initialBalance: (data['initialBalance'] as num?)?.toDouble() ?? 0.0,
      iconName: data['iconName'] ?? 'account_balance',
    );
  }
}
// lib/models/goal_model.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/models/goal_model.dart]

import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String? id;
  final String userId;
  final String title;        // Nome da meta (ex: "Gastos com iFood")
  final String category;     // Categoria que a meta vai monitorar (ex: "Alimentação")
  final double targetAmount; // Valor alvo (era 'target')
  final String type;         // 'limit' (limite de gasto) ou 'saving' (meta de economia)
  final DateTime deadline;   // Prazo final (era 'dueDate')

  // Campos calculados na tela, não são salvos no Firebase
  double currentAmount = 0.0; // Valor atual gasto/economizado
  
  // Getter que calcula o progresso em tempo real
  double get progress => (targetAmount > 0 ? (currentAmount / targetAmount) : 0.0).clamp(0.0, 1.0);

  GoalModel({
    this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.targetAmount,
    required this.type,
    required this.deadline,
    this.currentAmount = 0.0,
  });

  // Converte o objeto para um Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'category': category,
      'targetAmount': targetAmount,
      'type': type,
      'deadline': Timestamp.fromDate(deadline),
      // 'current' não é mais salvo
    };
  }

  // Cria um objeto GoalModel a partir de um documento lido do Firestore
  // Este factory agora é "inteligente" e consegue ler metas antigas e novas
  factory GoalModel.fromDoc(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Lógica para migrar dados antigos
    bool isOldModel = data.containsKey('description');
    
    return GoalModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      
      // Se for modelo antigo, usa 'description' como 'title'
      title: data['title'] ?? (isOldModel ? data['description'] : 'Meta sem título'),
      
      // Se for modelo antigo, usa 'description' como 'category'
      category: data['category'] ?? (isOldModel ? data['description'] : 'Outros'),
      
      // Consegue ler 'targetAmount' (novo) ou 'target' (antigo)
      targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 
                    (data['target'] as num?)?.toDouble() ?? 0.0,
      
      type: data['type'] ?? 'limit', // Padrão 'limit' se não existir
      
      // Consegue ler 'deadline' (novo) ou 'dueDate' (antigo)
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? 
                (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
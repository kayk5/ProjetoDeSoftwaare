// lib/services/goals_service.dart
// [Arquivo pbr-si-2024-2-p5-tias-t1-9155101-grupo_EcoFin/src/ecofin/lib/services/goals_service.dart]

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecofin/models/goal_model.dart';

class GoalsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String collection = 'goals';

  Future<void> addGoal(GoalModel goal) async {
    // Usa o toMap() do modelo corrigido
    await _db.collection(collection).add(goal.toMap());
  }

  Future<void> updateGoal(GoalModel goal) async {
    if (goal.id == null) throw ArgumentError('Goal id is null');
    // Usa o toMap() do modelo corrigido
    await _db.collection(collection).doc(goal.id).update(goal.toMap());
  }

  Future<void> deleteGoal(String id) async {
    await _db.collection(collection).doc(id).delete();
  }

  Stream<List<GoalModel>> streamUserGoals(String userId) {
    return _db
        .collection(collection)
        .where('userId', isEqualTo: userId)
        // ATENÇÃO: Ordenando pelo novo campo 'deadline'
        // Isso vai gerar o erro de índice no console de debug
        .orderBy('deadline', descending: false) 
        .snapshots()
        .map((snap) => snap.docs.map((d) => GoalModel.fromDoc(d)).toList());
  }
}
// lib/services/goal_notification_service.dart
// Serviço para gerenciar notificações de metas atingidas

import 'package:shared_preferences/shared_preferences.dart';

class GoalNotificationService {
  static const String _keyPrefix = 'goal_achieved_';

  // Verifica se uma meta já teve o pop-up exibido
  Future<bool> hasShownPopup(String goalId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$goalId') ?? false;
  }

  // Marca uma meta como já tendo exibido o pop-up
  Future<void> markPopupShown(String goalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$goalId', true);
  }

  // Limpa todas as marcações (útil para testes ou reset)
  Future<void> clearAllMarks() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}

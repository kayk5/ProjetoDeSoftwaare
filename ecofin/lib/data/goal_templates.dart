class GoalTemplate {
  final String id;
  final String title;
  final String description;
  final double defaultTarget;
  final String category; // social, environmental, personal

  const GoalTemplate({required this.id, required this.title, required this.description, required this.defaultTarget, required this.category});
}

const List<GoalTemplate> defaultGoalTemplates = [
  GoalTemplate(
    id: 'social_donation',
    title: 'Doação para ONG local',
    description: 'Arrecadar fundos para doações mensais a uma organização local',
    defaultTarget: 500.0,
    category: 'social',
  ),
  GoalTemplate(
    id: 'env_income_based',
    title: 'Meta baseada na renda líquida',
    description: 'Define uma meta de acordo com a renda líquida (receitas - despesas) do usuário; o valor será calculado automaticamente ao selecionar este template.',
    defaultTarget: 0.0,
    category: 'environmental',
  ),
  GoalTemplate(
    id: 'personal_emergency',
    title: 'Fundo de emergência',
    description: 'Reservar 3 meses de despesas como reserva de emergência',
    defaultTarget: 3000.0,
    category: 'personal',
  ),
];

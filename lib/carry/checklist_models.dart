class ChecklistItem {
  final String id;
  final String title;
  final String message;
  final String icon;
  final String type; // bring/avoid/action
  final int priority;
  final bool enabled;
  final Map<String, dynamic> rules;

  ChecklistItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.type,
    required this.priority,
    required this.enabled,
    required this.rules,
  });

  factory ChecklistItem.fromDoc(String id, Map<String, dynamic> m) {
    return ChecklistItem(
      id: id,
      title: (m['title'] ?? '').toString(),
      message: (m['message'] ?? '').toString(),
      icon: (m['icon'] ?? '').toString(),
      type: (m['type'] ?? 'bring').toString(),
      priority: (m['priority'] is int) ? m['priority'] as int : int.tryParse('${m['priority']}') ?? 0,
      enabled: (m['enabled'] ?? true) == true,
      rules: Map<String, dynamic>.from(m['rules'] ?? const {}),
    );
  }
}
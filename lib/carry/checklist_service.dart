import 'package:cloud_firestore/cloud_firestore.dart';
import 'checklist_models.dart';

class ChecklistService {
  final _db = FirebaseFirestore.instance;

  Future<List<ChecklistItem>> fetchEnabledItems() async {
    final snap = await _db
        .collection('checklist_items')
        .where('enabled', isEqualTo: true)
        .get();

    final items = snap.docs
        .map((d) => ChecklistItem.fromDoc(d.id, d.data()))
        .toList();

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items;
  }
}

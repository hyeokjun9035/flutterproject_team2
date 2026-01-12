import 'package:cloud_firestore/cloud_firestore.dart';

class NoticeRepository {
  final _col = FirebaseFirestore.instance.collection('community');

  /// 공지 생성
  Future<void> createNotice({
    required String title,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    await _col.add({
      'category': '공지사항',
      'title': title,
      'plain': content,
      'content': content,
      'images': imageUrls,
      'createdBy': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'active',
      'viewCount': 0,
      'commentCount': 0,
      'likeCount': 0,
    });
  }

  /// 공지 수정
  Future<void> updateNotice(
      String docId, {
        required String title,
        required String content,
      }) async {
    await _col.doc(docId).update({
      'title': title,
      'plain': content,
      'content': content,
    });
  }

  /// 공지 삭제
  Future<void> deleteNotice(String docId) async {
    await _col.doc(docId).update({
      'status': 'deleted',
    });
  }

  /// 공지 목록 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotices() {
    return _col
        .where('category', isEqualTo: '공지사항')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// ✅ [실제 데이터] 카테고리별 게시글 수 집계
  Future<Map<String, int>> getCategoryCounts() async {
    final categories = ["사건/이슈", "수다", "패션", "공지사항"];
    Map<String, int> counts = {};
    
    for (var cat in categories) {
      final snap = await _col.where('category', isEqualTo: cat).count().get();
      counts[cat] = snap.count ?? 0;
    }
    return counts;
  }

  /// ✅ [실제 데이터] 최근 7일간의 일별 게시글 수 집계
  Future<List<int>> getWeeklyPostCounts() async {
    List<int> weeklyData = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      
      final snap = await _col
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(day))
          .where('createdAt', isLessThan: Timestamp.fromDate(nextDay))
          .count()
          .get();
      
      weeklyData.add(snap.count ?? 0);
    }
    return weeklyData;
  }

  //관리자 숨김
  Future<void> hideNotice(String docId) async {
    await _col.doc(docId).update({
      'status': 'hidden',
      'deleted_at': FieldValue.serverTimestamp(),
    });
  }
}

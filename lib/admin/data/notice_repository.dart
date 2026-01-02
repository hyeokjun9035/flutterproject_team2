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
      'board_type': '공지사항',
      'title': title,
      'content': content,
      'image_urls': imageUrls,
      'user_id': 'admin',
      'is_notice': true,
      'status': 'active',
      'report_count': 0,
      'cdate': Timestamp.now(),
    });
  }

  /// 공지 수정
  Future<void> updateNotice(
      String docId, {
        required String title,
        required String content,
      }) async {
    // ✅ plain (새 형식)과 content (구 형식) 모두 업데이트
    await _col.doc(docId).update({
      'title': title,
      'plain': content,  // 새 형식
      'content': content,  // 구 형식 호환성
    });
  }

  /// 공지 삭제 (실삭제 or 상태변경 중 택1)
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

  //관리자 숨김 (목록에서 안 보이게)
  Future<void> hideNotice(String docId) async {
    await FirebaseFirestore.instance.collection('community').doc(docId).update({
      'status': 'hidden',
      'deleted_at': FieldValue.serverTimestamp(),
    });
  }

}

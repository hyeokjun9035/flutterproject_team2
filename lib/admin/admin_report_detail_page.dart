import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_project/admin/postDetailPage.dart';

class AdminReportDetailPage extends StatelessWidget {
  final String reportId;
  const AdminReportDetailPage({super.key, required this.reportId});

  // jgh260109----S 결과 텍스트 변환 헬퍼
  String _getResolutionText(String res) {
    switch (res) {
      case 'dismissed':
        return '무협의 종결';
      case 'deleted_post':
        return '게시글 삭제';
      case 'blocked_user':
        return '사용자 제재';
      case 'both':
        return '게시글 삭제 및 사용자 제재';
      case 'hidden_post':
        return '게시글 숨김';
      default:
        return '처리 완료';
    }
  }
  // jgh260109----E 결과 텍스트 변환 헬퍼

  Future<void> _closeReport({
    required String resolution,
    String adminMemo = '',
  }) async {
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {
        'status': 'closed',
        'resolution': resolution,
        'adminMemo': adminMemo,
        'handledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> handleReport({
    required String reportId,
    required bool deletePost,
    required int blockDays,
    String adminMemo = '',
  }) async {
    final fs = FirebaseFirestore.instance;
    final reportRef = fs.collection('reports').doc(reportId);
    final reportSnap = await reportRef.get();
    if (!reportSnap.exists) throw Exception('신고 문서가 없습니다.');

    final r = reportSnap.data() as Map<String, dynamic>;
    final postId = (r['postId'] ?? '').toString();
    final postRef = (r['postRef'] is DocumentReference)
        ? (r['postRef'] as DocumentReference)
        : fs.collection('community').doc(postId);

    final postAuthorUid = (r['postAuthorUid'] ?? '').toString();
    final userRef = fs.collection('users').doc(postAuthorUid);

    final batch = fs.batch();

    if (deletePost && postId.isNotEmpty) {
      batch.delete(postRef);
    }

    if (blockDays > 0 && postAuthorUid.isNotEmpty) {
      final until = DateTime.now().add(Duration(days: blockDays));
      batch.set(userRef, {
        'writeBlockedUntil': Timestamp.fromDate(until),
        'writeBlockedReason': '신고 처리에 의한 제한',
        'writeBlockedUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    String resolution = 'dismissed';
    if (deletePost && blockDays > 0)
      resolution = 'both';
    else if (deletePost)
      resolution = 'deleted_post';
    else if (blockDays > 0)
      resolution = 'blocked_user';

    batch.update(reportRef, {
      'status': 'closed',
      'resolution': resolution,
      'adminMemo': adminMemo,
      'handledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> _hidePost(String postId) async {
    await FirebaseFirestore.instance.collection('community').doc(postId).update(
      {'status': 'hidden', 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('reports').doc(reportId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        final data = snap.data!.data();
        if (data == null)
          return const Scaffold(body: Center(child: Text('신고 문서가 없습니다.')));

        final postId = (data['postId'] ?? '').toString();
        final title = (data['postTitle'] ?? '').toString();
        final reason = (data['reason'] ?? '').toString();
        final detail = (data['detail'] ?? '').toString();
        final status = (data['status'] ?? 'open').toString();
        final resolution = (data['resolution'] ?? '').toString();
        final adminMemo = (data['adminMemo'] ?? '').toString();
        final reporter =
            (data['reportedByEmail'] ?? data['reportedByUid'] ?? '').toString();

        final isClosed = status == 'closed';

        return Scaffold(
          appBar: AppBar(title: const Text('신고 상세')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '제목: $title',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _infoRow('postId', postId),
                _infoRow('신고자', reporter),
                _infoRow('사유', reason),
                if (detail.isNotEmpty) _infoRow('상세 내용', detail),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    const Text('상태: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isClosed ? Colors.grey : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isClosed ? '처리완료' : '미처리',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                // jgh260109----S 처리 결과 섹션 추가
                if (isClosed) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueGrey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Colors.blueGrey),
                            SizedBox(width: 6),
                            Text('처리 결과', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          ],
                        ),
                        const Divider(height: 20),
                        Text(_getResolutionText(resolution), 
                             style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        if (adminMemo.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('관리자 메모', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(adminMemo, style: const TextStyle(color: Colors.black87)),
                        ],
                      ],
                    ),
                  ),
                ],
                // jgh260109----E 처리 결과 섹션 추가

                const Divider(height: 32),

                if (!isClosed) ...[
                  const Text('조치 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: postId.isEmpty
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        AdminPostDetailPage(docId: postId),
                                  ),
                                ),
                          child: const Text('원글 보기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: postId.isEmpty
                              ? null
                              : () async {
                                  await _hidePost(postId);
                                  await _closeReport(resolution: 'hidden_post');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('원글 숨김 + 종료')),
                                    );
                                    Navigator.pop(context);
                                  }
                                },
                          child: const Text('숨김 처리'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await handleReport(
                            reportId: reportId,
                            deletePost: false,
                            blockDays: 0,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('무협의 처리(종료)')),
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('무협의(종료)'),
                      ),
                      ElevatedButton(
                        onPressed: postId.isEmpty
                            ? null
                            : () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('community')
                                      .doc(postId)
                                      .delete();
                                } catch (_) {}
                                await _closeReport(resolution: 'deleted_post');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('게시글 삭제 + 종료')),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                        child: const Text('게시글 삭제'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await handleReport(
                            reportId: reportId,
                            deletePost: false,
                            blockDays: 7,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('7일 작성 제한 + 종료')),
                            );
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('7일 제한'),
                      ),
                      ElevatedButton(
                        onPressed: postId.isEmpty
                            ? null
                            : () async {
                                await handleReport(
                                  reportId: reportId,
                                  deletePost: true,
                                  blockDays: 7,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('삭제 + 7일 제한 + 종료')),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                        child: const Text('삭제+7일'),
                      ),
                    ],
                  ),
                ] else ...[
                   Center(
                     child: OutlinedButton.icon(
                       icon: const Icon(Icons.article),
                       label: const Text('원글 링크 확인 (삭제 여부 확인)'),
                       onPressed: postId.isEmpty ? null : () => Navigator.push(
                         context,
                         MaterialPageRoute(builder: (_) => AdminPostDetailPage(docId: postId)),
                       ),
                     ),
                   ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

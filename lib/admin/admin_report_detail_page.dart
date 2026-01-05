import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_project/admin/postDetailPage.dart';

class AdminReportDetailPage extends StatelessWidget {
  final String reportId;
  const AdminReportDetailPage({super.key, required this.reportId});

  Future<void> _closeReport({
    required String resolution,
    String adminMemo = '',
  }) async {
    await FirebaseFirestore.instance.collection('reports').doc(reportId).update(
      {
        'status': 'closed', // ✅ open/closed만
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
    required int blockDays, // 0이면 제재 안 함
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

    // 1) (선택) 게시글 삭제
    if (deletePost && postId.isNotEmpty) {
      batch.delete(postRef);
    }

    // 2) (선택) 유저 제재
    if (blockDays > 0 && postAuthorUid.isNotEmpty) {
      final until = DateTime.now().add(Duration(days: blockDays));
      batch.set(userRef, {
        'writeBlockedUntil': Timestamp.fromDate(until),
        'writeBlockedReason': '신고 처리에 의한 제한',
        'writeBlockedUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3) 신고 문서 처리 완료로 변경
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
        final reporter =
            (data['reportedByEmail'] ?? data['reportedByUid'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(title: const Text('신고 상세')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '제목: $title',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('postId: $postId'),
                Text('신고자: $reporter'),
                Text('사유: $reason'),
                if (detail.isNotEmpty) Text('상세: $detail'),
                const SizedBox(height: 8),
                Text(
                  '상태: $status',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 24),

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
                                await _closeReport(
                                  resolution: 'hidden_post',
                                ); // ✅ 숨김은 숨김으로
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
                            const SnackBar(content: Text('무혐의 처리(종료)')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('무혐의(종료)'),
                    ),
                    ElevatedButton(
                      onPressed: postId.isEmpty
                          ? null
                          : () async {
                              try {
                                // ✅ 1) 글 삭제
                                await FirebaseFirestore.instance
                                    .collection('community')
                                    .doc(postId)
                                    .delete();
                              } catch (_) {}

                              // ✅ 2) 신고 닫기
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
                                  const SnackBar(
                                    content: Text('삭제 + 7일 제한 + 종료'),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            },
                      child: const Text('삭제+7일'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminPostDetailPage extends StatelessWidget {
  final String docId;
  const AdminPostDetailPage({super.key, required this.docId});

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      // final dt = ts.toDate();
      final dt = ts.toDate().toLocal(); // 시간표시 핵심
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Future<void> _deletePost(BuildContext context, Map<String, dynamic> data) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('삭제'),
        content: const Text('이 게시글을 삭제할까요? (복구 불가!)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (ok != true) return;

    // 1) Firestore 문서 삭제
    await FirebaseFirestore.instance.collection('community').doc(docId).delete();

    // 2) (선택) Storage 이미지 삭제 시도
    // image_urls가 downloadURL이라서 refFromURL로 삭제 가능
    final imageUrls = data['images'] ?? data['image_urls'];

    if (imageUrls is List) {
      for (final u in imageUrls) {
        if (u is String && u.startsWith('http')) {
          try {
            await FirebaseStorage.instance.refFromURL(u).delete();
          } catch (_) {
            // 규칙/권한/이미지 이미 삭제됨 등으로 실패할 수 있으니 무시
          }
        }
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('삭제 완료')),
      );
      Navigator.pop(context, true);
    }
  }

  // Future<void> _goEdit(BuildContext context, Map<String, dynamic> data) async {
  //   // TODO: 네 편집 페이지가 있으면 여기서 이동시키면 됨
  //   // 예: await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPostEditPage(docId: docId, initial: data)));
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('수정 화면 연결(예정)')),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('community').doc(docId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('게시글 상세'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // IconButton(
          //   tooltip: '수정',
          //   icon: const Icon(Icons.edit),
          //   onPressed: () async {
          //     final snap = await docRef.get();
          //     final data = snap.data();
          //     if (data == null) return;
          //     await _goEdit(context, data);
          //   },
          // ),
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final snap = await docRef.get();
              final data = snap.data();
              if (data == null) return;
              await _deletePost(context, data);
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('에러가 발생했습니다.'));
          }

          final doc = snapshot.data;
          final data = doc?.data();
          if (data == null) {
            return const Center(child: Text('게시글이 존재하지 않습니다.'));
          }

          // ✅ 제목 (둘 다 title이라 OK)
          final title = (data['title'] ?? '(제목 없음)').toString();

// ✅ 내용: 신스키마 plain 우선, 없으면 구스키마 content
          final content = (data['plain'] ?? data['content'] ?? '').toString();

// ✅ 카테고리: 신스키마 category 우선, 없으면 구스키마 board_type
          final category = (data['category'] ?? data['board_type'] ?? '미분류').toString();

// ✅ 작성자 닉네임: 신스키마 author.nickName 우선, 없으면 구스키마 nickName
          String nickName = 'unknown';
          final author = data['author'];
          if (author is Map) {
            nickName = (author['nickName'] ?? author['name'] ?? 'unknown').toString();
          } else {
            nickName = (data['nickName'] ?? 'unknown').toString();
          }

// ✅ 작성시간: 신스키마 createdAt 우선, 없으면 구스키마 cdate
          final createdAt = data['createdAt'] ?? data['cdate'];

// ✅ 신고/카운트: 구스키마 report_count 우선, 없으면 0
          final reportCount = (data['report_count'] ?? 0);

// ✅ 이미지: 신스키마 images 우선, 없으면 구스키마 image_urls
          final imageUrlsRaw = data['images'] ?? data['image_urls'];
          final List<String> imageUrls = (imageUrlsRaw is List)
              ? imageUrlsRaw.whereType<String>().toList()
              : <String>[];


          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(category),
                  _chip('작성자: $nickName'),
                  _chip('작성: ${_fmtTime(createdAt)}'),
                  _chip('신고: $reportCount'),
                ],
              ),


              const SizedBox(height: 16),

              // ✅ 이미지 영역 (여러 장이면 PageView, 1장이면 그냥 표시)
              if (imageUrls.isNotEmpty) ...[
                SizedBox(
                  height: 260,
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    itemBuilder: (_, i) {
                      final url = imageUrls[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, p) {
                              if (p == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (_, __, ___) => const Center(
                              child: Text('이미지를 불러오지 못했습니다.'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text('이미지 ${imageUrls.length}장', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
              ],

              // ✅ 본문
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  content.isEmpty ? '(내용 없음)' : content,
                  style: const TextStyle(fontSize: 15, height: 1.45),
                ),
              ),

              const SizedBox(height: 18),

              // ✅ 관리자 액션 버튼 (하단에도 배치)
              Row(
                children: [
                  // Expanded(
                  //   child: OutlinedButton.icon(
                  //     icon: const Icon(Icons.edit),
                  //     label: const Text('수정'),
                  //     onPressed: () => _goEdit(context, data),
                  //   ),
                  // ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      label: const Text('삭제', style: TextStyle(color: Colors.white)),
                      onPressed: () => _deletePost(context, data),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

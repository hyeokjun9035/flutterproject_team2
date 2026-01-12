import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/notice_repository.dart';
import '../notices/notice_create_page.dart';
import '../notices/notice_edit_page.dart';
import '../postDetailPage.dart';

// class NoticeListPage extends StatelessWidget {
class TitleListPage extends StatelessWidget {
  const TitleListPage({super.key});

  String _fmt(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final repo = NoticeRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 관리'),
        actions: [
          IconButton(
            tooltip: '공지 등록',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoticeCreatePage()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: repo.streamNotices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('에러: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('공지사항이 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final title = (data['title'] ?? '(제목 없음)').toString();
              
              // 작성자 정보 가져오기 (새 형식: author.nickName 또는 구 형식: user_id)
              String writer = 'unknown';
              final author = data['author'];
              if (author is Map) {
                writer = (author['nickName'] ?? author['name'] ?? author['uid'] ?? 'unknown').toString();
              } else {
                writer = (data['nickName'] ?? data['user_id'] ?? 'unknown').toString();
              }
              
              // 날짜 정보 가져오기 (새 형식: createdAt 또는 구 형식: cdate)
              final createdAt = data['createdAt'] ?? data['cdate'];
              
              // 이미지 개수
              final images = data['images'] as List? ?? [];
              final videos = data['videos'] as List? ?? [];
              final hasMedia = images.isNotEmpty || videos.isNotEmpty;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: const Icon(Icons.campaign, color: Colors.blue),
                  ),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('작성자: $writer · ${_fmt(createdAt)}'),
                      if (hasMedia)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (images.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.image, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${images.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              if (images.isNotEmpty && videos.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('·', style: TextStyle(color: Colors.grey)),
                                ),
                              if (videos.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text('${videos.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // ✅ 3단점 메뉴 주석처리 (상세 페이지에서 수정/삭제 가능)
                  // trailing: PopupMenuButton<String>(
                  //   onSelected: (v) async {
                  //     if (v == '수정') {
                  //       await Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => NoticeEditPage(docId: doc.id, initial: data),
                  //         ),
                  //       );
                  //     } else if (v == '삭제') {
                  //       final ok = await showDialog<bool>(
                  //         context: context,
                  //         builder: (_) => AlertDialog(
                  //           title: const Text('삭제'),
                  //           content: const Text('이 공지를 삭제(숨김)할까요?'),
                  //           actions: [
                  //             TextButton(
                  //               onPressed: () => Navigator.pop(context, false),
                  //               child: const Text('취소'),
                  //             ),
                  //             TextButton(
                  //               onPressed: () => Navigator.pop(context, true),
                  //               child: const Text('삭제'),
                  //             ),
                  //           ],
                  //         ),
                  //       );

                  //       if (ok == true) {
                  //         await repo.hideNotice(doc.id);
                  //         if (context.mounted) {
                  //           ScaffoldMessenger.of(context).showSnackBar(
                  //             const SnackBar(content: Text('삭제(숨김) 처리 완료')),
                  //           );
                  //         }
                  //       }
                  //     } else if (v == '상세보기') {
                  //       await Navigator.push(
                  //         context,
                  //         MaterialPageRoute(
                  //           builder: (_) => AdminPostDetailPage(docId: doc.id),
                  //         ),
                  //       );
                  //     }
                  //   },
                  //   itemBuilder: (_) => const [
                  //     PopupMenuItem(value: '상세보기', child: Text('상세보기')),
                  //     PopupMenuItem(value: '수정', child: Text('수정')),
                  //     PopupMenuItem(value: '삭제', child: Text('삭제(숨김)')),
                  //   ],
                  // ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminPostDetailPage(docId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/notice_repository.dart';
import '../notices/notice_create_page.dart';
import '../notices/notice_edit_page.dart';

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
              final userId = (data['user_id'] ?? 'admin').toString();
              final cdate = data['cdate'];

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.campaign)),
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('작성자: $userId · ${_fmt(cdate)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == '수정') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoticeEditPage(docId: doc.id, initial: data),
                          ),
                        );
                      } else if (v == '삭제') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('삭제'),
                            content: const Text('이 공지를 삭제(숨김)할까요?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('삭제'),
                              ),
                            ],
                          ),
                        );

                        if (ok == true) {
                          await repo.hideNotice(doc.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('삭제(숨김) 처리 완료')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: '수정', child: Text('수정')),
                      PopupMenuItem(value: '삭제', child: Text('삭제(숨김)')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminAlarmPage extends StatefulWidget {
  const AdminAlarmPage({super.key});

  @override
  State<AdminAlarmPage> createState() => _AdminAlarmPageState();
}

class _AdminAlarmPageState extends State<AdminAlarmPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendGlobalAlarm() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전체 알림(Alarm) 발송'),
        content: Text('모든 사용자에게 푸시 알림을 보낼까요?\n\n제목: $title\n내용: $body'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('발송', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _sending = true);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-northeast3')
          .httpsCallable('sendAdminNotification');

      await callable.call({
        'title': title,
        'body': body,
        'topic': 'community_topic',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('알림 발송 성공!')),
      );
      
      _titleCtrl.clear();
      _bodyCtrl.clear();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('발송 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _fmtTime(dynamic ts) {
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return DateFormat('MM/dd HH:mm').format(dt);
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('관리자 알림 발송(Alarm)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚨 긴급/공지 알림 발송',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  const Text('알림 제목', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: '알림 제목을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('알림 내용', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bodyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: '알림 상세 내용을 입력하세요',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _sendGlobalAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _sending
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('관리자가 즉시 알림 발송하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Divider(thickness: 1),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.history, size: 20),
                      SizedBox(width: 8),
                      Text('최근 발송 이력 (전체 사용자 대상)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // ✅ 최근 발송 내역 리스트 (Firestore 연동)
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('type', isEqualTo: 'admin_alarm') // ✅ receiverUid 필터를 제거
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('발송된 이력이 없습니다.', style: TextStyle(color: Colors.grey))),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return SliverList(
                delegate: SliverChildBuilderExecutor(
                  (context, index) {
                    final data = docs[index].data();
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 10),
                              Text(_fmtTime(data['createdAt']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(data['body'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                      ),
                    );
                  },
                  childCount: docs.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ListView 빌더를 위한 헬퍼 클래스 (SliverList용)
class SliverChildBuilderExecutor extends SliverChildBuilderDelegate {
  SliverChildBuilderExecutor(super.builder, {super.childCount});
}

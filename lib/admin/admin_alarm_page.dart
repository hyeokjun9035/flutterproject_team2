import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
          .httpsCallable('sendAdminNotification'); // 서버 함수명은 그대로 유지(일반적 관례)

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('관리자 알림 발송(Alarm)'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '알림 상세 내용을 입력하세요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('지금 알림 발송하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

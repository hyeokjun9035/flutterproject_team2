import 'package:flutter/material.dart';
import '../data/notice_repository.dart';

class NoticeEditPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> initial;

  const NoticeEditPage({super.key, required this.docId, required this.initial});

  @override
  State<NoticeEditPage> createState() => _NoticeEditPageState();
}

class _NoticeEditPageState extends State<NoticeEditPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final repo = NoticeRepository();

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = (widget.initial['title'] ?? '').toString();
    _contentCtrl.text = (widget.initial['content'] ?? '').toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await repo.updateNotice(
      widget.docId,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
    );
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지 수정'),
        actions: [
          TextButton(onPressed: _save, child: const Text('저장')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '제목')),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentCtrl,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(labelText: '내용'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

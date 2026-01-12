import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class Postdelete extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> initialData;

  const Postdelete({super.key, required this.postId, required this.initialData});

  @override
  State<Postdelete> createState() => _PostdeleteState();
}

class _PostdeleteState extends State<Postdelete> {
  late TextEditingController _contentController;
  late String _selectedBoard;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    _contentController = TextEditingController(text: widget.initialData['content']?.toString() ?? "");
    _selectedBoard = widget.initialData['board_type']?.toString() ?? "자유게시판";
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _deletePost() async {
    setState(() => _isProcessing = true);
    try {

      var rawUrls = widget.initialData['image_urls'];
      if (rawUrls is List) {
        for (var url in rawUrls) {
          try {
            await FirebaseStorage.instance.refFromURL(url.toString()).delete();
          } catch (e) {
            debugPrint("이미지 삭제 실패: $e");
          }
        }
      }

      await FirebaseFirestore.instance.collection('community').doc(widget.postId).delete();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("게시글이 삭제되었습니다.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _updatePost() async {
    if (_contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("내용을 입력해주세요.")));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('community').doc(widget.postId).update({
        'content': _contentController.text,
        'board_type': _selectedBoard,
        'udate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정이 완료되었습니다.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("수정 중 오류가 발생했습니다.")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    var rawUrls = widget.initialData['image_urls'];
    String displayUrl = "";
    if (rawUrls is List && rawUrls.isNotEmpty) {
      displayUrl = rawUrls[0].toString();
    } else if (rawUrls is String) {
      displayUrl = rawUrls;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        title: const Text("게시글 수정", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _updatePost,
            child: const Text("완료", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Center(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: displayUrl.isNotEmpty
                        ? Image.network(displayUrl, width: double.infinity, height: 200, fit: BoxFit.cover)
                        : Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.grey[100],
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),


            const Text("게시판 선택", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Container(
                color: Colors.white,
                child: DropdownButtonHideUnderline(
                  child: Container(
                    color: Colors.white,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedBoard,
                      items: ["자유게시판", "비밀 게시판"].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedBoard = value);
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),


            const Text("내용 수정", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: "소중한 의견을 남겨주세요.",
                filled: true,
                fillColor: Colors.grey[50],
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
            const SizedBox(height: 30),


            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteDialog(context),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                label: const Text("게시글 삭제하기", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("정말 삭제할까요?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("삭제된 게시글은 다시 복구할 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: _deletePost, child: const Text("삭제", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
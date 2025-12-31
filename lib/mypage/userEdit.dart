import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserEdit extends StatefulWidget {
  const UserEdit({super.key});

  @override
  State<UserEdit> createState() => _UserEditState();
}

class _UserEditState extends State<UserEdit> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _introController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  File? _image;
  String? _profileImageUrl;
  final picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 1. 데이터 불러오기: 'nickName' 필드 사용
  Future<void> _loadUserData() async {
    if (user == null) return;
    var snapshot = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (snapshot.exists) {
      setState(() {
        _nameController.text = snapshot['name'] ?? "";
        _nicknameController.text = snapshot['nickName'] ?? ""; // 수정됨
        _introController.text = snapshot['intro'] ?? "";
        _profileImageUrl = snapshot['profile_image_url'];
      });
    }
  }

  // 이미지 선택
  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  // 2. 프로필 업데이트: 'nickName' 필드 사용 및 Batch 처리
  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      String? finalImageUrl = _profileImageUrl;

      if (_image != null) {
        Reference ref = FirebaseStorage.instance.ref().child('profiles/${user!.uid}.jpg');
        await ref.putFile(_image!);
        finalImageUrl = await ref.getDownloadURL();
      }

      final userDoc = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      var snapshot = await userDoc.get();

      // 기존 닉네임 가져오기
      String oldNickname = snapshot.exists ? (snapshot.data()?['nickName'] ?? "") : "";
      String newNickname = _nicknameController.text.trim();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // users 문서 업데이트
      batch.update(userDoc, {
        'name': _nameController.text,
        'nickName': newNickname, // 수정됨
        'intro': _introController.text,
        'profile_image_url': finalImageUrl,
      });

      // usernames 컬렉션 중복 방지 로직
      if (oldNickname != newNickname && newNickname.isNotEmpty) {
        if (oldNickname.isNotEmpty) {
          batch.delete(FirebaseFirestore.instance.collection('usernames').doc(oldNickname));
        }
        batch.set(FirebaseFirestore.instance.collection('usernames').doc(newNickname), {
          'uid': user!.uid
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("프로필이 저장되었습니다.")));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오류가 발생했습니다: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. 회원 탈퇴: 실제 DB의 'nickName' 문서를 삭제하도록 보강
  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("회원 탈퇴", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("정말로 탈퇴하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("탈퇴", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final uid = user!.uid;

      // 입력창 값이 아닌 DB의 현재 닉네임 정보를 가져옴
      var userSnap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      String? currentNickname = userSnap.data()?['nickName'];

      if (currentNickname != null && currentNickname.isNotEmpty) {
        await FirebaseFirestore.instance.collection('usernames').doc(currentNickname).delete();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).delete();

      if (_profileImageUrl != null) {
        try {
          await FirebaseStorage.instance.ref().child('profiles/$uid.jpg').delete();
        } catch (_) {}
      }

      await user!.delete();

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("보안을 위해 다시 로그인한 후 탈퇴를 진행해 주세요.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("탈퇴 중 에러 발생: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("프로필 편집", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
            onPressed: _updateProfile,
            child: const Text("저장", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      backgroundImage: _getProfileImage(),
                      child: (_image == null && _profileImageUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    _buildInputField("이름", _nameController, Icons.person_outline),
                    const Divider(height: 1, indent: 55),
                    _buildNicknameField("닉네임", _nicknameController, Icons.alternate_email),
                    const Divider(height: 1, indent: 55),
                    _buildInputField("소개", _introController, Icons.notes, isLast: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: _deleteAccount,
              child: const Text("회원 탈퇴", style: TextStyle(color: Colors.redAccent, decoration: TextDecoration.underline, fontSize: 14)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {bool isLast = false}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: TextField(
        controller: controller,
        decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 5)),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildNicknameField(String label, TextEditingController controller, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 5)),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          GestureDetector(
            onTap: () async {
              String name = controller.text.trim();
              if (name.isEmpty) return;
              var doc = await FirebaseFirestore.instance.collection('usernames').doc(name).get();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(doc.exists ? "이미 사용 중인 닉네임입니다." : "사용 가능한 닉네임입니다."),
                  backgroundColor: doc.exists ? Colors.redAccent : Colors.green,
                ));
              }
            },
            child: const Text("중복확인", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_image != null) return FileImage(_image!);
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) return NetworkImage(_profileImageUrl!);
    return null;
  }
}
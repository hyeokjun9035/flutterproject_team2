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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    var snapshot = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    if (snapshot.exists) {
      setState(() {
        _nameController.text = snapshot['name'] ?? "";
        _nicknameController.text = snapshot['nickname'] ?? "";
        _introController.text = snapshot['intro'] ?? "";
        _profileImageUrl = snapshot['profile_image_url'];
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    try {
      String? finalImageUrl = _profileImageUrl;
      if (_image != null) {
        Reference ref = FirebaseStorage.instance.ref().child('profiles/${user?.uid}.jpg');
        await ref.putFile(_image!);
        finalImageUrl = await ref.getDownloadURL();
      }
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user?.uid);
      var oldSnapshot = await userDoc.get();
      String oldNickname = oldSnapshot['nickname'] ?? "";
      String newNickname = _nicknameController.text.trim();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      batch.update(userDoc, {
        'name': _nameController.text,
        'nickname': newNickname,
        'intro': _introController.text,
        'profile_image_url': finalImageUrl,


      });
      if (oldNickname != newNickname && newNickname.isNotEmpty) {
        if (oldNickname.isNotEmpty) {
          batch.delete(FirebaseFirestore.instance.collection('usernames').doc(oldNickname));
        }
        batch.set(FirebaseFirestore.instance.collection('usernames').doc(newNickname), {
          'uid': user?.uid
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("프로필이 저장되었습니다.")));
        Navigator.pop(context);
      }
    } catch (e) {
      print("업데이트 에러: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("취소", style: TextStyle(color: Colors.black, fontSize: 16)),
        ),
        actions: [
          TextButton(
            onPressed: _updateProfile, // 수정한 부분: 함수 직접 연결
            child: const Text("저장", style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    // backgroundImage에는 조건문 결과만 전달
                    backgroundImage: _getProfileImage(),
                    child: (_image == null && _profileImageUrl == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                        : null,
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _pickImage, // 함수만 바로 연결하거나 () => _pickImage() 형식으로 써야 합니다.
                    child: const Text(
                      "프로필 수정 하기",
                      style: TextStyle(color: Colors.deepPurple, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 1.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    _buildInputField("이름 : ", _nameController),
                    const Divider(height: 1, color: Colors.black),
                    _buildNicknameField("닉네임: ", _nicknameController),
                    const Divider(height: 1, color: Colors.black),
                    _buildInputField("소개 : ", _introController, isLast: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  } // 수정한 부분: 여기서 클래스를 닫았던 잘못된 중괄호를 제거했습니다.

  Widget _buildNicknameField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              String inputNickname = controller.text.trim(); // _nicknameController 대신 인자로 받은 controller 사용
              if (inputNickname.isEmpty) return;

              var doc = await FirebaseFirestore.instance
                  .collection('usernames')
                  .doc(inputNickname)
                  .get();

              if (doc.exists) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("이미 사용 중인 닉네임입니다."))
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("사용 가능한 닉네임입니다."))
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.black54),
              ),
              minimumSize: const Size(80, 30),
            ),
            child: const Text("중복확인", style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
  ImageProvider? _getProfileImage() {
    if (_image != null) {
      return FileImage(_image!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }
}
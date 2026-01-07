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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("회원 탈퇴", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("정말로 탈퇴하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("탈퇴", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인 상태가 아닙니다.")));
      return;
    }

    // 1) 비밀번호 확인
    final password = await _askPasswordForDelete();
    if (password == null || password.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 2) 재인증
      await _reauthenticateWithPassword(password);

      final uid = currentUser.uid;

// ✅ (추가) users/{uid} 아래 서브컬렉션 먼저 삭제
      await _cleanupUserSubcollections(uid);

// 3) Firestore + Storage + usernames + users 문서 삭제(네가 만든 함수)
      await _cleanupUserData(uid: uid);

// 4) Auth 삭제 (마지막)
      await currentUser.delete();

      if (!mounted) return;

// ✅ 먼저 화면 스택을 다 날리고 로그인으로 이동 (기존 화면 dispose 유도)
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/login',
            (route) => false,
        arguments: const {'deleted': true},
      );

    } on FirebaseAuthException catch (e) {
      // 비밀번호 틀림/재인증 실패
      if (e.code == 'wrong-password') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("비밀번호가 올바르지 않습니다.")));
      } else if (e.code == 'requires-recent-login') {
        // 이 코드는 재인증을 했는데도 뜨는 드문 케이스 대비
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("보안을 위해 다시 로그인 후 탈퇴해 주세요.")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("탈퇴 실패: ${e.message ?? e.code}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("탈퇴 중 에러 발생: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 비밀번호 입력 다이얼로그 + 재인증
  Future<String?> _askPasswordForDelete() async {
    final controller = TextEditingController();
    bool obscure = true;

    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("비밀번호 확인", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("탈퇴를 진행하려면 비밀번호를 입력해 주세요."),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      hintText: "비밀번호",
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("취소", style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text.trim()),
                  child: const Text("확인", style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reauthenticateWithPassword(String password) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("로그인 정보가 없습니다.");
    final email = currentUser.email;
    if (email == null || email.isEmpty) {
      throw Exception("이메일 계정이 아닙니다. (구글/애플 로그인이라면 재인증 방식이 달라요)");
    }

    final credential = EmailAuthProvider.credential(email: email, password: password);
    await currentUser.reauthenticateWithCredential(credential);
  }

  // Firestore + Storage 정리 (3개 삭제)
  Future<void> _cleanupUserData({required String uid}) async {
    await _anonymizeCommunityPosts(uid);
    final fs = FirebaseFirestore.instance;
    final st = FirebaseStorage.instance;

    final userRef = fs.collection('users').doc(uid);
    final userSnap = await userRef.get();

    final currentNickname = (userSnap.data()?['nickName'] as String?)?.trim();

    // Storage: 프로필 이미지 삭제 (없거나 실패해도 진행)
    try {
      await st.ref().child('profiles/$uid.jpg').delete();
    } catch (_) {}

    // Firestore: users + usernames 정리
    final batch = fs.batch();

    if (currentNickname != null && currentNickname.isNotEmpty) {
      final nickRef = fs.collection('usernames').doc(currentNickname);
      final nickSnap = await nickRef.get();

      // 내 uid가 맞는 경우에만 삭제 (안전장치)
      if (nickSnap.exists && nickSnap.data()?['uid'] == uid) {
        batch.delete(nickRef);
      }
    }

    if (userSnap.exists) {
      batch.delete(userRef);
    }

    await batch.commit();
  }

  Future<void> _deleteSubcollection({
    required DocumentReference parent,
    required String sub,
  }) async {
    final fs = FirebaseFirestore.instance;

    // 한번에 너무 많이 가져오면 위험 -> limit로 반복
    while (true) {
      final snap = await parent.collection(sub).limit(200).get();
      if (snap.docs.isEmpty) break;

      WriteBatch batch = fs.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _cleanupUserSubcollections(String uid) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // ✅ 여기에 네가 가진 서브컬렉션들을 나열
    await _deleteSubcollection(parent: userRef, sub: 'favorites');
    await _deleteSubcollection(parent: userRef, sub: 'location_history');
  }

  Future<void> _anonymizeCommunityPosts(String uid) async {
    final fs = FirebaseFirestore.instance;

    // ✅ 두 방식 모두 검색
    final q1 = await fs.collection('community')
        .where('createdBy', isEqualTo: uid)
        .get();

    final q2 = await fs.collection('community')
        .where('author.uid', isEqualTo: uid)
        .get();

    // ✅ 두 결과 합치기 (중복 제거)
    final seen = <String>{};
    final allDocs = <QueryDocumentSnapshot>{};

    for (final d in q1.docs) {
      if (seen.add(d.id)) allDocs.add(d);
    }
    for (final d in q2.docs) {
      if (seen.add(d.id)) allDocs.add(d);
    }

    WriteBatch batch = fs.batch();
    int count = 0;

    for (final doc in allDocs) {
      batch.update(doc.reference, {
        'authorDeleted': true,
        'author': {
          'uid': uid,
          'nickName': '탈퇴한 사용자',
          'name': '탈퇴한 사용자',
          'profile_image_url': '',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      count++;
      if (count == 450) {
        await batch.commit();
        batch = fs.batch();
        count = 0;
      }
    }

    if (count > 0) {
      await batch.commit();
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
              onPressed: _isLoading ? null : _deleteAccount,
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
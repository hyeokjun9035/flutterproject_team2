import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login.dart';

class JoinPage5 extends StatefulWidget {
  final String email;
  final String intro;
  final String profile_image_url;
  final String name;
  final String nickName;
  final String gender;
  final bool isLocationChecked;
  final bool isCameraChecked;
  final bool isAlramChecked;

  const JoinPage5({
    super.key,
    required this.email,
    required this.intro,
    required this.profile_image_url,
    required this.name,
    required this.nickName,
    required this.gender,
    required this.isLocationChecked,
    required this.isCameraChecked,
    required this.isAlramChecked,
  });

  @override
  State<JoinPage5> createState() => _JoinPage5State();
}

class _JoinPage5State extends State<JoinPage5> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  bool _isLoading = false;

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool> _finalizeSignup() async {
    if (_isLoading) return false;
    setState(() => _isLoading = true);

    try {
      final user = auth.currentUser;

      // ✅ JoinPage1에서 이미 createUserWithEmailAndPassword가 성공한 상태여야 함
      if (user == null) {
        _showMessage("가입 세션이 만료되었습니다. 처음부터 다시 시도해주세요.");
        return false;
      }

      final uid = user.uid;
      final nickKey = widget.nickName.trim().toLowerCase();

      await fs.runTransaction((tx) async {
        final nickRef = fs.collection("usernames").doc(nickKey);
        final nickSnap = await tx.get(nickRef);

        if (nickSnap.exists) {
          throw Exception("NICKNAME_EXISTS");
        }

        // 닉네임 예약
        tx.set(nickRef, {
          "uid": uid,
          "createdAt": FieldValue.serverTimestamp(),
        });

        // 유저 저장
        final userRef = fs.collection("users").doc(uid);
        tx.set(userRef, {
          "uid": uid,
          "email": widget.email.trim(),
          "intro": widget.intro,
          "profile_image_url": widget.profile_image_url,
          "name": widget.name,
          "nickName": widget.nickName,
          "gender": widget.gender,
          "isLocationChecked": widget.isLocationChecked,
          "isCameraChecked": widget.isCameraChecked,
          "isAlramChecked": widget.isAlramChecked,
          "writeBlockedUntil": null,
          "status": "active",
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

      return true;
    } on FirebaseException catch (e) {
      // Firestore 권한/규칙/네트워크 등
      _showMessage("저장 실패: ${e.message ?? e.code}");
      return false;
    } catch (e) {
      if (e.toString().contains("NICKNAME_EXISTS")) {
        _showMessage("중복된 닉네임 입니다.");
        return false;
      }
      _showMessage("회원가입 중 오류: $e");
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(150, 0, 0, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(100, 0, 0, 0),
              child: Image.asset("assets/joinIcon/colorSun.png", width: 30),
            ),
            Text("${widget.nickName}님 환영합니다!"),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                final ok = await _finalizeSignup();
                if (!mounted) return;

                if (ok) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                  );
                }
              },
              child: Text(_isLoading ? "처리중..." : "메인으로"),
            ),
          ],
        ),
      ),
    );
  }
}
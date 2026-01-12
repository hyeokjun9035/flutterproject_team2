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

        tx.set(nickRef, {
          "uid": uid,
          "createdAt": FieldValue.serverTimestamp(),
        });

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
          "alarmTime": "09:00",
          "writeBlockedUntil": null,
          "status": "active",
          "createdAt": FieldValue.serverTimestamp(),
        });
      });

      return true;
    } on FirebaseException catch (e) {
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
      backgroundColor: const Color(0xFFB2EBF2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F80ED),
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2F80ED),
              Color(0xFF56CCF2),
              Color(0xFFB2EBF2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Transform.translate(
                offset: const Offset(0, -40),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 30,
                        offset: Offset(0, 20),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Color(0xFF2F80ED),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "${widget.nickName}님 환영합니다!",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "회원가입이 성공적으로 완료되었습니다.\n이제 날씨 서비스를 이용하실 수 있어요 ☀️",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            final ok = await _finalizeSignup();
                            if (!mounted) return;

                            if (ok) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isLoading ? "처리중..." : "로그인 화면으로",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

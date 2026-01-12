import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_step2.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Auth를 사용하지 않지만, import는 유지

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: JoinPage1(
        email: "",
        pwd: "",
        checkPwd: "",
      ),
    );
  }
}

class JoinPage1 extends StatefulWidget {
  final String email;
  final String pwd;
  final String checkPwd;

  const JoinPage1({
    super.key,
    required this.email,
    required this.pwd,
    required this.checkPwd,
  });

  @override
  State<JoinPage1> createState() => _JoinPage1State();
}

class _JoinPage1State extends State<JoinPage1> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pwd = TextEditingController();
  final TextEditingController _checkPwd = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 가입 시작 시 기존 로그인 세션 정리
    FirebaseAuth.instance.signOut();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createAccountAndNext() async {
    if (_isLoading) return;

    final emailText = _email.text.trim();
    final pwdText = _pwd.text.trim();
    final checkPwdText = _checkPwd.text.trim();

    if (emailText.isEmpty) { _showMessage("이메일을 입력해주세요"); return; }
    if (pwdText.isEmpty) { _showMessage("비밀번호를 입력해주세요"); return; }
    if (checkPwdText.isEmpty) { _showMessage("비밀번호 확인을 해주세요"); return; }
    if (pwdText != checkPwdText) { _showMessage("비밀번호를 다시 확인해주세요"); return; }

    setState(() => _isLoading = true);

    try {
      // ✅ 여기서 이메일 중복이면 바로 예외로 걸립니다.
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailText,
        password: pwdText,
      );

      if (!mounted) return;

      // ✅ 이제부터는 uid를 Auth에서 쓰면 됨 (password 전달 불필요)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JoinPage2(email: emailText),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      switch (e.code) {
        case "email-already-in-use":
          _showMessage("이미 사용중인 이메일입니다.");
          break;
        case "invalid-email":
          _showMessage("이메일 형식이 올바르지 않습니다.");
          break;
        case "weak-password":
          _showMessage("비밀번호가 너무 약합니다. (6자리 이상)");
          break;
        case "network-request-failed":
          _showMessage("네트워크 오류입니다. 인터넷 연결을 확인해주세요.");
          break;
        case "operation-not-allowed":
          _showMessage("Firebase Auth에서 이메일/비밀번호 로그인이 비활성화되어 있어요.");
          break;
        default:
          _showMessage("회원가입 오류: ${e.code}\n${e.message ?? ""}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFB2EBF2),
      appBar: AppBar(
        backgroundColor: Color(0xFF2F80ED),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height:60),
                // 상단 타이틀/설명 (날씨 앱 톤)
                const SizedBox(height: 8),
                const Text(
                  "계정 만들기",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),


                const SizedBox(height: 70),

                // 폼 카드
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16,16,16,16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 25,
                        offset: Offset(0, 15),
                        color: Colors.black26,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDeco(
                          label: "이메일",
                          hint: "ex) test@naver.com",
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _pwd,
                        obscureText: true,
                        decoration: _inputDeco(
                          label: "비밀번호",
                          hint: "6자리 이상",
                          icon: Icons.lock_outline,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _checkPwd,
                        obscureText: true,
                        decoration: _inputDeco(
                          label: "비밀번호 확인",
                          icon: Icons.lock_reset_outlined,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 다음 버튼
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createAccountAndNext,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: const Color(0xFF2F80ED),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isLoading ? "처리중..." : "다음",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 안내 문구
                      const Text(
                        "다음 단계에서 닉네임과 프로필을 설정할 수 있어요.",
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 하단 작은 안내
                const Text(
                  "작성하면 위치 기반 날씨 서비스를 이용할 수 있어요 ☀️",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원가입")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ... (UI 동일)

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email, size: 30),
                labelText: "이메일: ex)test@naver.com",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _pwd,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: "비밀번호 (6자리 이상)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _checkPwd,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: "비밀번호 확인",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _createAccountAndNext,
              child: Text(_isLoading ? "처리중..." : "다음"),
            ),
          ],
        ),
      ),
    );
  }
}
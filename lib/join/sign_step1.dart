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
  // 🔑 'firebaseFirestore' -> 'FirebaseFirestore' 타입 수정
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pwd = TextEditingController();
  final TextEditingController _checkPwd = TextEditingController();

  //trim() == 공백제거
  Future<bool> _join() async {
    final emailText = _email.text.trim();
    final pwdText = _pwd.text.trim();
    final checkPwdText = _checkPwd.text.trim();

    // 1. 빈값 확인 및 즉시 종료 (return false)
    if (emailText.isEmpty) {
      _showMessage("이메일을 입력해주세요");
      return false; // 🛑 오류 시 즉시 종료
    }
    if (pwdText.isEmpty) {
      _showMessage("비밀번호를 입력해주세요");
      return false; // 🛑 오류 시 즉시 종료
    }
    if (checkPwdText.isEmpty) {
      _showMessage("비밀번호 확인을 해주세요");
      return false; // 🛑 오류 시 즉시 종료
    }

    // 2. 비밀번호 일치 확인
    if (pwdText != checkPwdText) {
      _showMessage("비밀번호를 다시 확인해주세요");
      return false; // 🛑 오류 시 즉시 종료
    }

    // 3. 🔑 Firestore에서 이메일 중복 검사
    try {
      final QuerySnapshot result = await fs.collection('users')
          .where('email', isEqualTo: emailText) // emailText 사용
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        _showMessage('이미 사용중인 이메일입니다.');
        return false; // 🛑 중복 시 즉시 종료
      }
    } catch (e) {
      // Firestore 접근 중 오류 발생
      _showMessage('이메일 중복 확인 중 오류발생: ${e.toString()}');
      return false; // 🛑 오류 시 즉시 종료
    }

    // 4. 모든 검사 통과
    return true;
  } // 🔑 _join() 함수 닫는 중괄호 복원


  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg))
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pwd.dispose();
    _checkPwd.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 200), // 패딩 조정

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 380, 0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
            //이미지 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 350, 200),
              child: Image.asset("assets/joinIcon/cloud.png", width: 50,),
            ),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email, size: 30,),
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
            const SizedBox(height: 24,),
            TextField(
              controller: _checkPwd,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: "비밀번호 확인",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),


            ElevatedButton(
              onPressed: () async {
                bool success = await _join();

                if (success) {
                  // 🔑 Auth를 사용하지 않으므로, 이메일과 비밀번호를 JoinPage2로 전달합니다.
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>
                          JoinPage2(
                            email: _email.text.trim(),
                            password: _pwd.text.trim()

                          ),
                      ),
                    );
                  }
                }
              },
              child: const Text("다음"), // const 추가
            )
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_project/admin/admin_home_page.dart';
import 'sign_step1.dart';
import 'package:flutter_project/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwdController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pwd = _pwdController.text.trim();

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: pwd,
      );

      // ... (관리자/일반 사용자 처리 로직은 동일)
      final uid = userCredential.user!.uid; // 유지

      if (email == "admin@gmail.com") {
        _showMessage("관리자 로그인 성공!");
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else {
        _showMessage("로그인 성공!"); // 일반 사용자 로그인 성공 메시지 추가
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }

    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
      // ✅ 이 두 경우를 통합하여 사용자에게 모호한(보안적인) 메시지를 제공합니다.
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential': // 추가: 최신 버전에서 이 코드가 반환될 수 있습니다.
          message = '이메일 또는 비밀번호가 일치하지 않습니다.'; // 또는 '등록되지 않은 계정입니다.'
          break;

        case 'invalid-email':
          message = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-disabled':
          message = '비활성화된 계정입니다. 관리자에게 문의하세요.';
          break;
        case 'network-request-failed':
          message = '네트워크 오류입니다. 인터넷 연결을 확인해주세요.';
          break;
        case 'too-many-requests':
          message = '로그인 시도가 너무 많습니다. 잠시 후 다시 시도해주세요.';
          break;
        default:
          message = '로그인 실패: ${e.message ?? e.code}';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('알 수 없는 오류 발생: $e');
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  bool _shownDeleteMessage = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_shownDeleteMessage) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['deleted'] == true) {
      _shownDeleteMessage = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("탈퇴가 완료되었습니다.")),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _pwdController.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // 🔹 로고 영역 (Stack으로 텍스트를 이미지 위에 띄움)
                Column(
                  children: [
                    // ✅ 로고 위에 텍스트 오버레이
                    Positioned(
                      child: Text(
                        "오늘 어때",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10,
                              color: Colors.black38,
                              // offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          "assets/joinIcon/logo.png",
                          width: 180,
                          filterQuality: FilterQuality.high,
                        ),


                      ],
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      "오늘 날씨, 한 번에 확인",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 🔹 로그인 카드
                Container(
                  padding: const EdgeInsets.all(16),
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "이메일",
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pwdController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: "비밀번호",
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: const Color(0xFF2F80ED),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "로그인",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const JoinPage1(
                                      email: "",
                                      pwd: "",
                                      checkPwd: "",
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                side: const BorderSide(
                                  color: Color(0xFF2F80ED),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "회원가입",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2F80ED),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  "로그인하면 위치 기반 날씨를 제공해요",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

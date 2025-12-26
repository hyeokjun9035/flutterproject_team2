import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'join1.dart';
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
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    String id = _idController.text.trim();
    String password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      _showMessage("아이디와 비밀번호를 입력해주세요");
      return;
    }

    try {
      // Firestore에서 join 컬렉션에서 아이디/비밀번호 확인
      var snapshot = await fs
          .collection("join")
          .where("id", isEqualTo: id)
          .where("password", isEqualTo: password)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _showMessage("로그인 성공!");
        // TODO: 로그인 성공 후 다음 페이지로 이동
        // Navigator.push(context, MaterialPageRoute(builder: (_) => HomePage()));
      } else {
        _showMessage("아이디 또는 비밀번호가 올바르지 않습니다");
      }
    } catch (e) {
      _showMessage("로그인 중 오류 발생: $e");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("로그인")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 100, color: Colors.white),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "아이디",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "비밀번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // ElevatedButton(
            //     onPressed: (){
            //       Navigator.push(
            //           context,
            //           MaterialPageRoute(builder: (_)=>(
            //
            //           ))
            //       );
            //     },
            //     child: Text("로그인")
            // )
            ElevatedButton(
                onPressed: (){
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage1(

                      ))
                  );
                },
                child: Text("회원가입")
            )
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_project/admin/admin_home_page.dart';
import 'join1.dart';
import 'package:flutter_project/home/home_page.dart';




class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    final FirebaseFirestore fs = FirebaseFirestore.instance;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final snapshot = await fs
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    if (snapshot.docs.isEmpty) {
      _showMessage("해당 이메일이 존재하지 않습니다"); //사실상 아이디
      return;
    }

    final userDoc = snapshot.docs.first;

    //밑에 할려고 시도한 거
    // if (userDoc["password"] == "admin") {
    //   _showMessage("로그인 성공!");
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (_) => const AdminHomePage()),
    //   );
    // }

    // =========================================================
    // 1. 하드코딩된 관리자 계정 체크 로직 추가
    // =========================================================
    if (email == "admin" && password == "admin") {
      _showMessage("관리자 로그인 성공!");
      // mounted 상태 확인
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        // AdminHomePage로 바로 이동
        MaterialPageRoute(builder: (_) => const AdminHomePage()),
      );
      return; // 관리자 로그인이 성공했으므로 함수를 종료합니다.
    }
    ///////////////////////////////////////////////////////////

    if (userDoc["password"] == password ) {
      _showMessage("로그인 성공!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      _showMessage("비밀번호를 확인해주세요");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "이메일",
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


            ElevatedButton(
              onPressed: _login,
              child: const Text("로그인"),
            ),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const JoinPage1()),
                );
              },
              child: const Text("회원가입"),
            ),
          ],



        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_project/admin/admin_home_page.dart';
import 'join1.dart';
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

  //firebase Auth 인스턴스 _login 함수 밖에서 초기화
  final FirebaseAuth _auth = FirebaseAuth.instance;


    //jgh251230 관리자 로그인 끌어올림---S
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
    //jgh251230 관리자 로그인 끌어올림---E
    
    final snapshot = await fs
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    // if (snapshot.docs.isEmpty) {
    //   _showMessage("해당 이메일이 존재하지 않습니다"); //사실상 아이디
    //   return;
    // }

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
    // if (email == "admin" && password == "admin") {
    //   _showMessage("관리자 로그인 성공!");
    //   // mounted 상태 확인
    //   if (!mounted) return;
    //   Navigator.pushReplacement(
    //     context,
    //     // AdminHomePage로 바로 이동
    //     MaterialPageRoute(builder: (_) => const AdminHomePage()),
    //   );
    //   return; // 관리자 로그인이 성공했으므로 함수를 종료합니다.
    // }
    ///////////////////////////////////////////////////////////

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pwd,
      );

      _showMessage("로그인 성공!");

      //mounted상태 확인
      if(!mounted) return;

      //HomePage로 이동(로그인 성공 시)
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      if(e.code == 'user-not-found') {
        message = '등록되지 않은 이메일 입니다.';
      } else if (e.code == 'wrong-password') {
        message = '비밀번호가 일치하지 않습니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else {
        message = '로그인 중 오류가 발생했습니다';
      }
      _showMessage(message);
    } catch (e) {
      //기타 오류 처리
      _showMessage("알 수 없는 오류 발생");
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
    _pwdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("로그인")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
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
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "이메일",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwdController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "비밀번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),


            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                ElevatedButton(
                  onPressed: _login,
                  child: const Text("로그인"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinPage1(
                        email: "",
                        pwd: "",
                        checkPwd: "",
                      )

                      ),
                    );
                  },
                  child: const Text("회원가입"),
                ),
              ],
            )

          ],



        ),
      ),
    );
  }
}

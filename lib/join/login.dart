import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_project/admin/admin_home_page.dart';
import 'sign_step1.dart';
import 'package:flutter_project/home/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_project/join/Google_Login.dart';
import 'kakaoLogin.dart';

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


  @override
  void initState() {
    super.initState();
    //이메일/비밀번호 로그인 폼을 보여주기 전에 인증 상태를 확인
    _checkIfAlreadySignedIn();
  }

  void _checkIfAlreadySignedIn(){
    final user = FirebaseAuth.instance.currentUser;
    if(user != null){
      //이미 로그인된 상태면 즉시 홈 페이지로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()));
      });
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pwd = _pwdController.text.trim();


    print('$email');
    print('${pwd.length}');
    //--------------관리자 로그인---------------
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: pwd
      );

      //이 시점에서 관리자는 인증된 상태가 됨
      final uid = userCredential.user!.uid;    //final = 한 번 할당하면 변경 불가, !uid = uid가 null이 아님

      if(email == "admin@gmail.com") {
        _showMessage("관리자 로그인 성공!");
        if(!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminHomePage()),
        );
      } else {
        //일반 사용자 로그인
        // _showMessage("로그인 성공!");
        if(!mounted) return;
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }

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
        padding: const EdgeInsets.fromLTRB(16,16,16,150),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(padding: const EdgeInsets.only(right: 30),
                child:
                ElevatedButton(
                  onPressed: _login,
                  child: const Text("로그인"),
                ),
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
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding (
                padding: const EdgeInsets.fromLTRB(0,20,10,0),
                child:
                GestureDetector(
                    onTap: (){
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => GoogleLogin())
                      );
                    },
                    child: Image.asset("assets/joinIcon/google.png", width: 50),

                ),
    ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(10,20,0,0),
                child:
                GestureDetector(
                    onTap: (){
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_)=> kakaoLogin())
                      );
                    },
                    child: Image.asset("assets/joinIcon/kakao.png", width: 50,),
                )
    ),




              ],
            )


          ],



        ),
      ),
    );
  }
}

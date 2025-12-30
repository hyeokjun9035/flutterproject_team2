import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'join2.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebase 초기화 설정
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    //JoinPage1은 초기상태 (빈 값)로 시작
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
  //Firebase Auth 인스턴스 추가
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore fs = FirebaseFirestore.instance;

  final TextEditingController _email = TextEditingController();
  final TextEditingController _pwd = TextEditingController();
  final TextEditingController _checkPwd = TextEditingController(); //db에 들어갈건지 말건지 결정


  //trim() == 공백제거
  Future<bool> _join() async {
    if (_pwd.text.trim() != _checkPwd.text.trim()) {
      _showMessage("비밀번호를 다시 확인해주세요");
      return false; //실패
    }

    try {
      //firebase auth를 사용하여 계정 생성
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pwd.text.trim(),
      );
      //인증 성공 시 발급된 UID를 사용하여 Firestore에 나머지 정보 저장
      String uid = userCredential.user!.uid; //고유 UID획득


      return true;
    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = '비밀번호는 6자리 이상이어야 합니다.';
      } else if (e.code == 'email-already-in-use') {
        message = '이미 사용중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다';
      } else {
        message = '회원가입 중 오류가 발생했습니다: ${e.message}';
      }
      _showMessage(message);
      return false;
    } catch (e) {
      _showMessage("오류발생");
      return false;
    }
  }


  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg))
    );
  }




  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10,0,10,200),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 380, 0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
           //이미지 추가
           Padding(
               padding: const EdgeInsets.fromLTRB(10,0,350,200),
             child:Image.asset("assets/joinIcon/cloud.png", width: 50,),
           ),



            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress, //이메일 키보드 타입 설정
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email, size: 30,) ,
                labelText: "이메일: ex)test@naver.com",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwd,
              obscureText: true,//입력값을 숨김
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.password),
                labelText: "비밀번호 (6자리 이상)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),
            TextField(
              controller: _checkPwd,
              obscureText: true,//입력값을 숨김
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
                  String? uid = _auth.currentUser?.uid;
                  if (mounted && uid != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) =>
                          JoinPage2(
                            email: _email.text.trim(),
                            uid: uid,
                          ),
                      ),
                    );
                  }
                }
              },
                child: Text("다음"),
                )
          ],
          
        ),
      ),
    );
  }
}




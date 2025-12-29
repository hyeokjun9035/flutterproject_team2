import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'join1.dart';
import 'package:flutter_project/community/Community.dart';
import 'package:flutter_project/home/home_page.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();   // Flutter 엔진 준비
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // firebase_options.dart에서 불러옴
  );
  //아무거나함
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

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login() async {
    final FirebaseFirestore fs = FirebaseFirestore.instance;

    //입력값
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    //firestore에서 해당 이메일 문서 찾기
    QuerySnapshot snapshot = await fs
        .collection("users")
        .where("email", isEqualTo: email)
        .get();

    if(snapshot.docs.isEmpty){
      print("해당 이메일이 존재하지 않습니다");
      return;
    }
    //첫번째 문서 가져오기 (문서들의 리스트에서 첫번째 문서만 가져오기)
    var userDoc = snapshot.docs.first;
    // print(userDoc["password"]);
    //비번비교
    if(userDoc["password"] == password) {
      print("로그인 성공!");
      Navigator.push(
          context,
          MaterialPageRoute(builder: (_)=>HomePage(

          ))
      );
    }else{
    print("비밀번호를 확인해주세요");
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
                onPressed: () async{
                  await _login();
                },
                child: Text("로그인")
            ),
            ElevatedButton(
                onPressed: () async{
                  await Navigator.push(
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

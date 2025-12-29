import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'join3.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,

    );
  }
}
class JoinPage2 extends StatefulWidget {
  final String name;
  final String age;
  final String phone;

  const JoinPage2({
    super.key,
    required this.name,
    required this.age,
    required this.phone,

});

  @override
  State<JoinPage2> createState() => _JoinPage2State();
}
class _JoinPage2State extends State<JoinPage2>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _nickName = TextEditingController();

  Future<void> _join() async{
    await fs.collection("users").add({
      "email" : _email.text,
      "password" : _password.text,
      "nickName" : _nickName.text
    });

  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10,10,10,150),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [


            TextField(
              controller: _email,
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email),
                labelText: "이메일",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.onetwothree, size: 30,) ,
                labelText: "비밀번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nickName,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.onetwothree, size: 30,) ,
                labelText: "닉네임",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),
            ElevatedButton(
                onPressed: ()  {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage3(
                          name: widget.name,
                          age: widget.age,
                          phone: widget.phone,
                          email: _email.text,
                          password: _password.text,
                          nickName: _nickName.text,
                      ))
                  );
                },
                child: Text("다음")
            )
          ],

        ),
      ),
    );
  }
}




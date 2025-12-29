import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'join2.dart';

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
      home: const JoinPage1(),
    );
  }
}
class JoinPage1 extends StatefulWidget {
  const JoinPage1({super.key});

  @override
  State<JoinPage1> createState() => _JoinPage1State();
}
class _JoinPage1State extends State<JoinPage1>{

  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _phone = TextEditingController();


  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10,0,10,250),

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
              controller: _name,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                labelText: "이름",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _age,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.onetwothree, size: 30,) ,
                labelText: "나이",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              // obscureText: true,//입력값을 숨김
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: "전화번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),


          ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_)=>JoinPage2(
                      name: _name.text,
                      age: _age.text,
                      phone: _phone.text,
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




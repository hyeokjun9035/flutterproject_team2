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
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();

  Future<void> _join() async{
    print("===============================  tests");
    final test = await fs.collection("users").doc("zz").get();
    print(test.data());

    await fs.collection("users").add({
      "name" : _name.text,
      "age" : _age.text,
      "phone" : _phone.text,
      "email" : _email.text,
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
            //이미지 추가
            // Image.asset("java2.jpg"),

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
              obscureText: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.phone),
                labelText: "전화번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),


          ElevatedButton(
              onPressed: () async{
                await _join();
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (_)=>JoinPage2(
                //
                //   ))
                // );
              },
              child: Text("다음")
          )
          ],
          
        ),
      ),
    );
  }
}




import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'join4.dart';


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
class JoinPage3 extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String email;
  final String password;
  final String nickName;

  const JoinPage3({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
    required this.password,
    required this.nickName,
  });

  @override
  State<JoinPage3> createState() => _JoinPage3State();
}
class _JoinPage3State extends State<JoinPage3>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String? _gender;

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(10,0,10,390),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 300, 0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
            //이미지 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(10,0,350,200),
              child:Image.asset("assets/joinIcon/cloud.png", width: 50,),
            ),
            // ✅ 성별 선택 박스
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: const InputDecoration(
                labelText: "성별",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "M", child: Text("남")),
                DropdownMenuItem(value: "F", child: Text("녀")),
              ],
              onChanged: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),

            const SizedBox(height: 24,),
            ElevatedButton(
                onPressed: ()  {

                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage4(
                        name: widget.name,
                        age: widget.age,
                        phone: widget.phone,
                        email: widget.email,
                        password: widget.password,
                        nickName: widget.nickName,
                        gender: _gender ?? "", //성별 값 전달

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




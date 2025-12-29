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


  Future<void> _join() async{
    await fs.collection("users").add({
      "gender" : _gender
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




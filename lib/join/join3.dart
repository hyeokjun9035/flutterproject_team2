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
      home: const JoinPage3(),
    );
  }
}
class JoinPage3 extends StatefulWidget {
  const JoinPage3({super.key});

  @override
  State<JoinPage3> createState() => _JoinPage3State();
}
class _JoinPage3State extends State<JoinPage3>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String? _gender;


  Future<void> _Join() async{
    await fs.collection("join").add({
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
                DropdownMenuItem(value: "남", child: Text("남")),
                DropdownMenuItem(value: "녀", child: Text("녀")),
              ],
              onChanged: (value) {
                setState(() {
                  _gender = value;
                });
              },
            ),




            const SizedBox(height: 24,),
            ElevatedButton(
                onPressed: (){
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage4(

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




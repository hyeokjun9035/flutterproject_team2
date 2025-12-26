import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'joinFinal.dart';


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
      home: const JoinPage4(),
    );
  }
}
class JoinPage4 extends StatefulWidget {
  const JoinPage4({super.key});

  @override
  State<JoinPage4> createState() => _JoinPage4State();
}
class _JoinPage4State extends State<JoinPage4>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
 bool isLocationChecked = false;
 bool isCameraChecked = false;
 bool isAlramChecked = false;


  Future<void> _join() async{
    await fs.collection("users").add({
      "isLocationChecked" : isLocationChecked,
      "isCameraChecked" : isCameraChecked,
      "isAlramChecked" :  isAlramChecked

    });

  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Padding(
                padding:const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 100),
              child: Text("기타 및 관련 서비스에 동의해주세요"),
            ),


            CheckboxListTile(
              title: const Text("위치기반 서비스에 동의합니다 (필수)"),
              value: isLocationChecked,
              onChanged: (value) {
                setState(() {
                  isLocationChecked = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text("카메라 서비스에 동의합니다 (필수)"),
              value: isCameraChecked,
              onChanged: (value) {
                setState(() {
                  isCameraChecked = value!;
                });
              },
            ),
            CheckboxListTile(
              title: const Text("알림 및 기타 서비스에 동의합니다 (선택)"),
              value: isAlramChecked,
              onChanged: (value) {
                setState(() {
                  isAlramChecked = value!;
                });
              },
            ),

            ElevatedButton(
                onPressed: () async{
                  await _join();
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage5(

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




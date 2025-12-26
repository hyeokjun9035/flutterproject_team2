import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';


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
      home: const JoinPage5(),
    );
  }
}
class JoinPage5 extends StatefulWidget {
  const JoinPage5({super.key});

  @override
  State<JoinPage5> createState() => _JoinPage5State();
}
class _JoinPage5State extends State<JoinPage5>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  bool isLocationChecked = false;
  bool isCameraChecked = false;
  bool isAlramChecked = false;


  Future<void> JoinPage5() async{
    await fs.collection("join").add({

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
            Text("oo님 환영합니다!"),

            ElevatedButton(
                onPressed: (){
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>LoginPage(

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




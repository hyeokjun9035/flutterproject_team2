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

    );
  }
}
class JoinPage5 extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String email;
  final String password;
  final String nickName;
  final String gender;
  final bool isLocationChecked;
  final bool isCameraChecked;
  final bool isAlramChecked;

  const JoinPage5({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
    required this.password,
    required this.nickName,
    required this.gender,
    required this.isLocationChecked,
    required this.isCameraChecked,
    required this.isAlramChecked
  });

  @override
  State<JoinPage5> createState() => _JoinPage5State();
}
class _JoinPage5State extends State<JoinPage5>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  bool isLocationChecked = false;
  bool isCameraChecked = false;
  bool isAlramChecked = false;


  Future<void> JoinPage5() async{
  //   await fs.collection("users").add({
  //     "name": widget.name,
  //     "age": widget.age,
  //     "phone": widget.phone,
  //     "email": widget.email,
  //     "password": widget.password,
  //     "nickName": widget.nickName,
  //     "gender": widget.gender,
  //     "isLocationChecked": widget.isLocationChecked,
  //     "isCameraChecked": widget.isCameraChecked,
  //     "isAlramChecked": widget.isAlramChecked
  //   });
  //
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: Text("회원가입"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(150, 0, 0, 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(100, 0,0,0),
                child: Image.asset("assets/joinIcon/colorSun.png", width: 30,)
            ),
            Text("${widget.nickName}님 환영합니다!"),


            ElevatedButton(
                onPressed: () async{
                  await JoinPage5();
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>LoginPage(

                      ))
                  );
                },
                child: Text("메인으로")
            )
          ],

        ),
      ),
    );
  }
}




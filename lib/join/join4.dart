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

    );
  }
}
class JoinPage4 extends StatefulWidget {
  final String name;
  final String age;
  final String phone;
  final String email;
  final String password;
  final String nickName;
  final String gender;

  const JoinPage4({
    super.key,
    required this.name,
    required this.age,
    required this.phone,
    required this.email,
    required this.password,
    required this.nickName,
    required this.gender
  });

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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 270,0),
                child: Image.asset("assets/joinIcon/sun.png", width: 30,)
            ),
            //이미지 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(10,0,350,200),
              child:Image.asset("assets/joinIcon/cloud.png", width: 50,),
            ),
            Padding(
                padding:const EdgeInsetsGeometry.fromLTRB(0, 0, 0, 20),
              child: Text("기타 및 관련 서비스에 동의해주세요"),
            ),

            Row(
              children: [

                Padding(padding: const EdgeInsets.fromLTRB(90, 0, 90, 50)),
                Icon(Icons.location_on),
                Icon(Icons.camera_alt),
                Icon(Icons.edit_notifications),
              ]
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
                          name: widget.name,
                          age: widget.age,
                          phone: widget.phone,
                          email: widget.email,
                          password: widget.password,
                          nickName: widget.nickName,
                          gender: widget.gender, //성별 값 전달
                        isLocationChecked: isLocationChecked,
                          isCameraChecked: isCameraChecked,
                          isAlramChecked: isAlramChecked

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




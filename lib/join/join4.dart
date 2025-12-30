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
  final String email;
  final String intro;
  final String name;
  final String profile_image_url;
  final String nickName;
  final String gender;

  const JoinPage4({
    super.key,
    required this.email,
    required this.intro,
    required this.name,
    required this.profile_image_url,
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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 250),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), ),
                Icon(Icons.location_on, size: 50,),
                Icon(Icons.camera_alt, size: 50,),
                Icon(Icons.edit_notifications, size: 50,),
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
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_)=>JoinPage5(
                          email: widget.email,
                          intro: widget.intro,
                          name: widget.name,
                          nickName: widget.nickName,
                          profile_image_url: widget.profile_image_url,
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




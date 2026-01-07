import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_step4.dart';


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
  //authcation 과 동일한 uid 사용을 위해서 끌어옴
  final String email;
  final String name;
  final String intro;
  final String nickName;
  final String profile_image_url;


  const JoinPage3({
    super.key,
    //authcation 과 동일한 uid 사용을 위해서 끌어옴
    required this.email,
    required this.name,
    required this.intro,
    required this.nickName,
    required this.profile_image_url,
  });

  @override
  State<JoinPage3> createState() => _JoinPage3State();
}


class _JoinPage3State extends State<JoinPage3>{
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  String _gender = "male";

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
              padding: const EdgeInsets.fromLTRB(10,0,350,160),
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
                DropdownMenuItem(value: "male", child: Text("남")),
                DropdownMenuItem(value: "female", child: Text("녀")),
              ],
              onChanged: (String? value) {
                if(value != null)
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
                        //authcation 과 동일한 uid 사용을 위해서 끌어옴
                        email: widget.email,
                        name: widget.name,
                        intro: widget.intro,
                        profile_image_url: widget.profile_image_url,
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
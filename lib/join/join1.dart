import 'package:flutter/material.dart';

void main(){
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'join Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const JoinPage(),
    );
  }
}
class JoinPage extends StatefulWidget {
  const JoinPage({super.key});

  @override
  State<JoinPage> createState() => _JoinPageState();
}
class _JoinPageState extends State<JoinPage>{
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  void _login(){
    String name = _nameController.text;
    String password = _ageController.text;
    String phone = _phoneController.text;
    String email = _emailController.text;

    //     //서버 연동 필요
    //     if(email == true && password == true){
    //       ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text("로그인 성공")),
    //       );
    //   }else{
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(content: Text("로그인 성공")),
    // );
    // }
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "이름",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: "나이",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "전화번호",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),
            TextField(
              controller: _emailController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "이메일",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24,),

          ],
        ),
      ),
    );
  }
}




import 'package:flutter/material.dart';

void main(){
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}
  class _LoginPageState extends State<LoginPage>{
    final TextEditingController _emailController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();

    void _login(){
      String email = _emailController.text;
      String password = _passwordController.text;

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
      appBar: AppBar(),
       body: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(

                radius: 60,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 100, color: Colors.white,
         )
                ),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "아이디",
                  border: OutlineInputBorder(),
            ),
          ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "비밀번호",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24,),
              ElevatedButton(
                onPressed: _login,
                child: const Text("로그인"),

       ),


      ],

         ),

  ),
      );
  }
  }




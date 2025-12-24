import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              onPressed: (){},
              icon: Icon(Icons.menu)
          ),
          title: Text("커뮤니티"),
          elevation: 0,
          actions: [
            IconButton(
                onPressed: (){},
                icon: Icon(Icons.add)
            )
          ],
        ),

        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: '홈',
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.comment),
                label: '커뮤니티'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '마이페이지',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_active),
              label: '알림',
            ),
          ],
        ),

        // body: ,
      ),
    );
  }
}

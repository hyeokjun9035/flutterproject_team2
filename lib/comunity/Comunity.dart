import 'package:flutter/material.dart';
import '../headandputter/putter.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
      currentIndex: 1, // 커뮤니티
      body: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu),
          ),
          title: const Text("커뮤니티"),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: const Center(
          child: Text('커뮤니티 화면'),
        ),
      ),
    );
  }
}

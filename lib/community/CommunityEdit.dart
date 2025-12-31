import 'package:flutter/material.dart';
import '../headandputter/putter.dart';

class CommunityEdit extends StatefulWidget {
  const CommunityEdit({super.key});

  @override
  State<CommunityEdit> createState() => _CommunityEditState();
}

class _CommunityEditState extends State<CommunityEdit> {
  @override
  Widget build(BuildContext context) {
    return PutterScaffold(
        currentIndex: 1,
        body: Scaffold(
          appBar: AppBar(
            title: Text("수정"),
          ),
        ),
    );
  }
}

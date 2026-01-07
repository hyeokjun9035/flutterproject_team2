import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationView extends StatelessWidget {
  const NotificationView({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("알림"),
        centerTitle: true,
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text("로그인이 필요합니다."))
          : StreamBuilder<QuerySnapshot>(
        // 1. 나에게 온 알림만 최신순으로 가져오기
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('receiverUid', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("에러: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("알림이 없습니다."));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String type = data['type'] ?? '';
              final String senderNick = data['senderNickName'] ?? '누군가';
              final String postTitle = data['postTitle'] ?? '게시글';
              final bool isRead = data['isRead'] ?? false;
              final Timestamp? ts = data['createdAt'] as Timestamp?;
              final String timeStr = ts != null
                  ? DateFormat('MM/dd HH:mm').format(ts.toDate())
                  : '';

              // 알림 유형에 따른 메시지 구성
              String message = "";
              IconData iconData = Icons.notifications;
              Color iconColor = Colors.blue;

              if (type == 'like') {
                message = "'$postTitle' 글에 좋아요를 눌렀습니다.";
                iconData = Icons.favorite;
                iconColor = Colors.red;
              } else if (type == 'comment') {
                message = "'$postTitle' 글에 댓글을 남겼습니다.";
                iconData = Icons.chat_bubble;
                iconColor = Colors.green;
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  child: Icon(iconData, color: iconColor, size: 20),
                ),
                title: Text(
                  "$senderNick님이 $message",
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(timeStr, style: const TextStyle(fontSize: 12)),
                tileColor: isRead ? Colors.transparent : Colors.blue.withOpacity(0.05),
                onTap: () {
                  // 2. 클릭 시 읽음 처리
                  docs[index].reference.update({'isRead': true});

                  // 3. 해당 게시글로 이동 (필요 시 구현)
                  // Navigator.push(context, MaterialPageRoute(...));
                },
              );
            },
          );
        },
      ),
    );
  }
}
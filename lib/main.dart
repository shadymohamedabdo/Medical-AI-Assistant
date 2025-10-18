import 'package:flutter/material.dart';

import 'chat_screen.dart';

void main() {
  runApp(const NursingAssistantApp());
}

class NursingAssistantApp extends StatelessWidget {
  const NursingAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nursing Assistant Bot',
      debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChatScreen(),
        ));
  }
}

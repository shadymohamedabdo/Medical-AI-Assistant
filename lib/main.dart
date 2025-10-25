import 'package:flutter/material.dart';
import 'package:nursing_help/shared_pref.dart';

import 'chat_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await MyPrefs.init(); // نجهز الـ instance هنا
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

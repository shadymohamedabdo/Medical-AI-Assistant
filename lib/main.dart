import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nursing_help/chat_controller.dart';
import 'package:nursing_help/hive.dart';

import 'chat_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  Get.lazyPut(() => ChatController(), fenix: true);

  await MyPrefs.init(); // نجهز الـ instance هنا
  runApp(const NursingAssistantApp());
}

class NursingAssistantApp extends StatelessWidget {
  const NursingAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChatScreen(),
        ));
  }
}

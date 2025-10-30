import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nursing_help/hive.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'ai_service.dart';

class ChatController extends GetxController {
  // UI
  final RxList<Map<String, String>> messages = <Map<String, String>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isListening = false.obs;
  Rx<Map<String, String>?> replyToMessage = Rx<Map<String, String>?>(null);

  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  // Services
  final AiService aiService = AiService();
  late stt.SpeechToText speech;

  // Storage
  final RxList<Map<String, dynamic>> allChats = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    speech = stt.SpeechToText();
    _initializeChats();
  }

  Future<void> _initializeChats() async {
    await loadAllChats();
    if (allChats.isEmpty) {
      await startNewChat();
    } else {
      await loadLastChat();
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    controller.dispose();
    super.onClose();
  }

  // JSON Helpers
  Map<String, dynamic> _messageToJson(Map<String, String> msg) => Map<String, dynamic>.from(msg);
  Map<String, String> _messageFromJson(Map<String, dynamic> json) => json.map((k, v) => MapEntry(k, v.toString()));
  List<Map<String, dynamic>> _messagesToJson(List<Map<String, String>> msgs) => msgs.map(_messageToJson).toList();
  List<Map<String, String>> _messagesFromJson(List<dynamic> list) =>
      list.cast<Map<String, dynamic>>().map(_messageFromJson).toList();

  // Load & Save
  Future<void> loadAllChats() async {
    final saved = MyPrefs.getString('all_chats');
    if (saved == null) return;

    try {
      final List<dynamic> decoded = jsonDecode(saved);
      allChats.value = decoded.map((e) {
        final map = Map<String, dynamic>.from(e);
        final msgs = map['messages'] as List<dynamic>? ?? [];
        map['messages'] = _messagesFromJson(msgs);
        return map;
      }).toList();
    } catch (e) {
      allChats.clear();
    }
  }

  Future<void> saveAllChats() async {
    final List<Map<String, dynamic>> toSave = allChats.map((chat) {
      final copy = Map<String, dynamic>.from(chat);
      copy['messages'] = _messagesToJson(chat['messages'] as List<Map<String, String>>);
      return copy;
    }).toList();
    await MyPrefs.setString('all_chats', jsonEncode(toSave));
  }

  // Chat Management
  Future<void> loadLastChat() async {
    if (allChats.isNotEmpty) {
      openChat(allChats.last);
    }
  }

  void openChat(Map<String, dynamic> chat) {
    // احفظ الحالية
    if (allChats.isNotEmpty && messages.isNotEmpty) {
      allChats.last['messages'] = List<Map<String, String>>.from(messages);
    }

    // اجعل المحادثة المختارة = last
    allChats.remove(chat);
    allChats.add(chat);

    // افتح الرسائل
    messages.value = _messagesFromJson(chat['messages'] as List<dynamic>);
    saveAllChats(); // احفظ الترتيب
    scrollToBottom();
  }

  Future<void> startNewChat() async {
    if (allChats.isNotEmpty && messages.isNotEmpty) {
      allChats.last['messages'] = List<Map<String, String>>.from(messages);
      await saveAllChats();
    }

    messages.clear();
    final newChat = {
      "id": DateTime.now().millisecondsSinceEpoch.toString(),
      "title": "محادثة جديدة",
      "messages": <Map<String, String>>[],
    };
    allChats.add(newChat);
    await saveAllChats();
  }

  // Send Message
  Future<void> sendMessage(String message, {bool isEdited = false}) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    String finalMessage = trimmed;
    if (replyToMessage.value != null) {
      final orig = replyToMessage.value!['text']!;
      finalMessage = 'الرسالة الأصلية: "$orig"\n\nرد المستخدم: $trimmed';
    }

    if (allChats.isEmpty) await startNewChat();

    if (messages.isEmpty && allChats.isNotEmpty) {
      String title = trimmed;
      if (title.length > 25) title = '${title.substring(0, 25)}...';
      allChats.last['title'] = title;
    }

    if (!isEdited) {
      messages.add({'role': 'user', 'text': trimmed});
    }

    isLoading.value = true;
    scrollToBottom();

    try {
      final reply = await aiService.getBotReply(finalMessage, messages);
      messages.add({'role': 'bot', 'text': reply});
    } catch (e) {
      messages.add({'role': 'bot', 'text': 'حدث خطأ، حاول مرة أخرى.'});
    } finally {
      isLoading.value = false;
      replyToMessage.value = null;
    }

    allChats.last['messages'] = List<Map<String, String>>.from(messages);
    await saveAllChats();
    scrollToBottom();
  }

  // Edit
  void editMessage(int index, String oldText) {
    final editCtrl = TextEditingController(text: oldText);
    Get.defaultDialog(
      title: "تعديل الرسالة",
      radius: 15,
      content: Column(
        children: [
          TextField(
            controller: editCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "الرسالة الجديدة...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Get.back(), child: const Text("إلغاء")),
              const SizedBox(width: 10),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.teal),
                onPressed: () async {
                  final newText = editCtrl.text.trim();
                  if (newText.isEmpty || newText == oldText) {
                    Get.back();
                    return;
                  }

                  messages[index]['text'] = newText;
                  if (index + 1 < messages.length && messages[index + 1]['role'] == 'bot') {
                    messages.removeAt(index + 1);
                  }

                  allChats.last['messages'] = List<Map<String, String>>.from(messages);
                  await saveAllChats();
                  Get.back();

                  await sendMessage(newText, isEdited: true);
                  mySnackBar(message: 'تم التعديل', color: Colors.green);
                },
                child: const Text("تعديل", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Copy
  void copyBotMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    mySnackBar(message: 'تم النسخ', color: Colors.green);
  }

  // Voice
  void listen() async {
    if (isListening.value) {
      isListening.value = false;
      speech.stop();
      if (controller.text == 'جاري الاستماع...') controller.clear();
      return;
    }

    final ok = await speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          isListening.value = false;
          if (controller.text == 'جاري الاستماع...') controller.clear();
        }
      },
      onError: (e) => mySnackBar(message: 'خطأ الميكروفون', color: Colors.red),
    );

    if (!ok) {
      mySnackBar(message: 'الميكروفون غير متاح', color: Colors.red);
      return;
    }

    isListening.value = true;
    controller.text = 'جاري الاستماع...';
    speech.listen(
      localeId: 'ar_EG',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      onResult: (r) {
        if (r.recognizedWords.isNotEmpty) {
          controller.text = r.recognizedWords;
          controller.selection = TextSelection.fromPosition(
            TextPosition(offset: r.recognizedWords.length),
          );
        }
      },
    );
  }

  // Image
  Future<void> pickImage({required ImageSource source}) async {
    final xFile = await ImagePicker().pickImage(source: source);
    if (xFile == null) return;

    final compressed = await FlutterImageCompress.compressAndGetFile(
      xFile.path,
      "${xFile.path}_c.jpg",
      quality: 70,
    );

    if (compressed == null) return;

    messages.add({
      'role': 'user',
      'text': '',
      'imagePath': compressed.path,
    });

    allChats.last['messages'] = List<Map<String, String>>.from(messages);
    await saveAllChats();
    scrollToBottom();
  }

  // Delete All
  Future<void> deleteChat() async {
    await MyPrefs.remove('all_chats');
    allChats.clear();
    messages.clear();
    await startNewChat();
    mySnackBar(message: 'تم مسح السجل', color: const Color(0xFFEF5350));
  }

  // Delete By ID
  Future<void> deleteChatById(String id) async {
    final wasCurrent = allChats.isNotEmpty && allChats.last['id'] == id;
    allChats.removeWhere((c) => c['id'] == id);
    await saveAllChats();

    if (allChats.isEmpty) {
      await startNewChat();
    } else if (wasCurrent) {
      openChat(allChats.last);
    }
  }

  // Scroll
  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // SnackBar
  void mySnackBar({required String message, required Color color}) {
    Get.rawSnackbar(
      messageText: Center(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
      backgroundColor: color,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      borderRadius: 0,
      margin: EdgeInsets.zero,
    );
  }
}
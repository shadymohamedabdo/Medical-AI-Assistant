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

class ChatController extends GetxController{
  final RxList<Map<String, String>> messages = <Map<String, String>>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isListening = false.obs;
  Rx<Map<String, String>?> replyToMessage = Rx<Map<String, String>?>(null);

  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  late stt.SpeechToText speech;
  final AiService aiService = AiService();
   String kChatHistory = 'chat_history';


  @override
  void onInit() {
    super.onInit();
    speech = stt.SpeechToText();
    loadOldMessages();

  }
  @override
  void onClose() {
    scrollController.dispose();
    controller.dispose();
    super.onClose();
  }

  Future<void> loadOldMessages() async {
    try {
      final saved = MyPrefs.getString(kChatHistory);
      if (saved != null) {
        final List decoded = jsonDecode(saved);
        messages.addAll(decoded.map((e) => Map<String, String>.from(e)));
        scrollToBottom();
      }
    } catch (e) {
      mySnackBar(message: '⚠️ خطأ في تحميل سجل المحادثات', color: Colors.red);
    }
  }

  Future<void> saveMessages() async {
    if (messages.isEmpty) return;
    if (messages.length > 100) {
      final oldMessages = messages.sublist(0, messages.length - 100);
      for (var msg in oldMessages) {
        if (msg.containsKey('imagePath')) {
          await File(msg['imagePath']!).delete(); // حذف الصور القديمة
        }
      }
      messages.removeRange(0, messages.length - 100);
    }
    await MyPrefs.setString(kChatHistory, jsonEncode(messages));
  }  void scrollToBottom() {
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

  Future<void> sendMessage(String message, {bool isEdited = false}) async {

    String finalMessage = message;
    // ✅ لو المستخدم بيرد على رسالة معينة
    if (replyToMessage.value != null) {
      finalMessage =
      'الرسالة الأصلية: "${replyToMessage.value!['text']}"\n\nرد المستخدم: $message';
    }

    if (!isEdited) {
      messages.add({'role': 'user', 'text': message});
      isLoading.value = true;
    } else {
      isLoading.value = true;
    }
    scrollToBottom();
    // ✅ البوت بيرد بناءً على الرسالة المختارة
    final reply = await aiService.getBotReply(finalMessage, messages);
    messages.add({'role': 'bot', 'text': reply});
    isLoading.value = false;
    replyToMessage.value = null; // ✅ نلغي وضع الرد بعد الإرسال
    await saveMessages();
    scrollToBottom();
  }

  void editMessage(int index, String oldText) {
    final editController = TextEditingController(text: oldText);

    Get.defaultDialog(
      title: "✏️ تعديل الرسالة",
      titleStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      radius: 15,
      content: Column(
        children: [
          TextField(
            controller: editController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: "اكتب الرسالة الجديدة هنا...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // زر إلغاء
              TextButton(
                child: const Text("إلغاء"),
                onPressed: () {
                  Get.back();
                },
              ),
              const SizedBox(width: 10),
              // زر تعديل (نفس شكل زر حذف لكن بلون تركوازي)
              TextButton(
                child: const Text(
                  "تعديل",
                  style: TextStyle(
                    color: Colors.teal, // اللون الأساسي عندك
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () async {
                  final newText = editController.text.trim();
                  if (newText.isEmpty || newText == oldText) return;
                  messages[index]['text'] = newText;

                  // لو الرسالة اللي بعدها من البوت، نحذفها لأنها خلاص مش مناسبة بعد التعديل
                  if (index + 1 < messages.length &&
                      messages[index + 1]['role'] == 'bot') {
                    messages.removeAt(index + 1);
                  }

                  await saveMessages();
                  Get.back(); // يقفل الديالوج

                  // نخلي البوت يرد على الرسالة المعدلة
                  await sendMessage(newText, isEdited: true);
                  mySnackBar(message: 'تم تعديل الرسالة بنجاح ✅', color: Colors.green);
                  },
              ),
            ],
          ),
        ],
      ),
    );
  }


  void copyBotMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    mySnackBar(message: '✅ تم نسخ الرد إلى الحافظة', color: Colors.green);

  }

  void listen() async {
    if (!isListening.value) {
      bool available = await speech.initialize(

        onStatus: (value) {

          if (value == 'done' || value == 'notListening') {
          isListening.value = false;
            speech.stop();
            // لو المستخدم وقف الكلام نرجع النص فاضي بعد التوقف
            if (controller.text == '🎙️ جاري الاستماع...') {
              controller.clear();
            }
          }
        },
        onError: (error) {
        isListening.value = false;
        mySnackBar(message: '⚠️ في مشكلة في الميكروفون: ${error.errorMsg}', color: Colors.green);

        },
      );

      if (available) {
          isListening.value = true;
          controller.text = '🎙️ جاري الاستماع...'; // ✅ يظهر النص أول ما يبدأ التسجيل
        speech.listen(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'ar_EG',
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
                controller.value = TextEditingValue(
                  text: val.recognizedWords,
                  selection: TextSelection.fromPosition(
                    TextPosition(offset: val.recognizedWords.length),
                  ),
                );
            }
          },
        );
      } else {
        mySnackBar(message: '🎤 الميكروفون مش متاح دلوقتي، جرّب تاني.', color: Colors.red);

      }
    } else {
     isListening.value = false;
      speech.stop();
      controller.clear(); // 🛑 لو ضغط تاني يوقف التسجيل ويفضي الحقل
    }
  }
  Future<void> pickImage({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        image.path,
        "${image.path}_compressed.jpg",
        quality: 70,
      );
      messages.add({
        'role': 'user',
        'text': '',
        'imagePath': compressedImage!.path,
      });
      await saveMessages();
      scrollToBottom();
    }
  }  Future<void> deleteChat() async {
    await MyPrefs.remove('chat_history');
    messages.clear();
  }
  void mySnackBar({required String message,required Color color}) {
    Get.rawSnackbar(
      messageText:  Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      backgroundColor: color,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      borderRadius: 0,
      margin: EdgeInsets.zero,
    );
  }


}
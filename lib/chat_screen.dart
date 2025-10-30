import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nursing_help/chat_controller.dart';
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chatState = Get.find<ChatController>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('المساعد الطبي الذكي'),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () {
              Get.defaultDialog(
                title: "تأكيد الحذف",
                titleStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                radius: 15,
                content: Column(
                  children: [
                    const Text(
                      "هل أنت متأكد إنك عايز تمسح سجل المحادثة بالكامل؟ 😢",
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text(
                            "إلغاء",
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            Get.back();
                          },
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          child: const Text(
                            "مسح",
                            style: TextStyle(
                              color: Color(0xFFEF5350),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () async {
                            chatState.deleteChat();
                            Get.back();
                            Get.rawSnackbar(
                              messageText: const Center(
                                child: Text(
                                  'تم مسح سجل المحادثة بنجاح ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              backgroundColor: const Color(0xFFEF5350),
                              snackPosition: SnackPosition.BOTTOM,
                              duration: const Duration(seconds: 2),
                              borderRadius: 0,
                              margin: EdgeInsets.zero,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Obx(() {
          final chats = chatState.allChats;
          return ListView(
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.teal),
                child: Text('💬 سجل المحادثات', style: TextStyle(color: Colors.white, fontSize: 22)),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('محادثة جديدة'),
                onTap: () async {
                  await chatState.startNewChat();
                  Get.back();
                },
              ),
              const Divider(),
              ...chats.map((chat) {
                return ListTile(
                  title: Text(chat['title'] ?? 'بدون عنوان'),
                  onTap: () {
                    Get.back();
                    chatState.openChat(chat);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await chatState.deleteChatById(chat['id']);
                    },
                  ),
                );
              }).toList(),
            ],
          );
        }),
      ),
      body: Obx(() {
        // ✅ لو بيعمل تحميل أول ما التطبيق يفتح
        if (chatState.isLoading.value && chatState.messages.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          );
        }

        // ✅ بعد ما يخلص تحميل الرسائل
        return Column(
          children: [
            Expanded(
              child: Obx(
                    () => ListView.builder(
                  controller: chatState.scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: chatState.messages.length,
                  itemBuilder: (_, i) {
                    final msg = chatState.messages[i];
                    final isUser = msg['role'] == 'user';
                    return messagesDesign(isUser, chatState, msg, i);
                  },
                ),
              ),
            ),

            // ⏳ مؤشر التحميل أثناء انتظار رد البوت فقط
            Obx(
                  () => chatState.isLoading.value &&
                  chatState.messages.isNotEmpty // ✅ فقط لما يرد البوت
                  ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(color: Colors.teal),
              )
                  : const SizedBox(),
            ),

            // 💬 الرسالة اللي هترد عليها
            Obx(
                  () => chatState.replyToMessage.value != null
                  ? replyToMessage(chatState)
                  : const SizedBox(),
            ),

            // 🖊️ حقل الكتابة
            messageButton(chatState),
          ],
        );
      }),
    );
  }

  Padding messageButton(ChatController chatState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: chatState.controller,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5,
              onEditingComplete: () {
                if (chatState.controller.text.isNotEmpty) {
                  chatState.sendMessage(chatState.controller.text);
                  chatState.controller.clear();
                }
              },
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.teal,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.camera_alt, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'camera') {
                      chatState.pickImage(source: ImageSource.camera);
                    } else {
                      chatState.pickImage(source: ImageSource.gallery);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'camera', child: Text('📸 الكاميرا')),
                    PopupMenuItem(value: 'gallery', child: Text('🖼️ المعرض')),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                backgroundColor: Colors.teal,
                child: IconButton(
                  icon: Icon(
                    Icons.mic,
                    color: chatState.isListening.value
                        ? Colors.red
                        : Colors.white,
                  ),
                  onPressed: () {
                    chatState.listen();
                  },
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                backgroundColor: Colors.teal,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    if (chatState.controller.text.isNotEmpty) {
                      chatState.sendMessage(chatState.controller.text);
                      chatState.controller.clear();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Container replyToMessage(ChatController chatState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chatState.replyToMessage.value!['text']!.length > 60
                  ? '${chatState.replyToMessage.value!['text']!.substring(0, 60)}...'
                  : chatState.replyToMessage.value!['text']!,
              style: const TextStyle(
                color: Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => chatState.replyToMessage.value = null,
          ),
        ],
      ),
    );
  }

  GestureDetector messagesDesign(
      bool isUser, ChatController chatState, Map<String, String> msg, int i) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 10 && !isUser) {
          chatState.replyToMessage.value = msg;
        }
      },
      child: Align(
        alignment:
        isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isUser ? Colors.teal[400] : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 0),
              bottomRight: Radius.circular(isUser ? 0 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.3),
                offset: const Offset(1, 2),
                blurRadius: 3,
              ),
            ],
          ),
          child: msg.containsKey('imagePath')
              ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(msg['imagePath']!),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          )
              : isUser
              ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg['text']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () {
                  chatState.editMessage(i, msg['text']!);
                },
                child: const Icon(Icons.edit,
                    size: 15, color: Colors.white70),
              ),
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                msg['text']!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () =>
                      chatState.copyBotMessage(msg['text']!),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy,
                          size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'نسخ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

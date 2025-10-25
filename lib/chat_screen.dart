import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';
import 'package:nursing_help/shared_pref.dart';
import 'ai_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Map<String, String>? _replyToMessage;

  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadOldMessages();
  }

  Future<void> _loadOldMessages() async {
    final saved = MyPrefs.getString('chat_history');
    if (saved != null) {
      final List decoded = jsonDecode(saved);
      setState(() {
        _messages.addAll(decoded.map((e) => Map<String, String>.from(e)));
      });
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    }
  }

  Future<void> _saveMessages() async {
    await MyPrefs.setString('chat_history', jsonEncode(_messages));
  }

  Future<void> sendMessage(String message, {bool isEdited = false}) async {
    String finalMessage = message;

    // ✅ لو المستخدم بيرد على رسالة معينة
    if (_replyToMessage != null) {
      finalMessage =
      'الرسالة الأصلية: "${_replyToMessage!['text']}"\n\nرد المستخدم: $message';
    }

    if (!isEdited) {
      setState(() {
        _messages.add({'role': 'user', 'text': message});
        _isLoading = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    _scrollToBottom();

    // ✅ البوت بيرد بناءً على الرسالة المختارة
    final reply = await _aiService.getBotReply(finalMessage, _messages);

    setState(() {
      _messages.add({'role': 'bot', 'text': reply});
      _isLoading = false;
      _replyToMessage = null; // ✅ نلغي وضع الرد بعد الإرسال
    });

    await _saveMessages();
    _scrollToBottom();
  }

  void _editMessageDialog(int index, String oldText) {
    final editController = TextEditingController(text: oldText);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('✏️ تعديل الرسالة'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isEmpty) return;
              setState(() {
                _messages[index]['text'] = newText;
              });

              //بيشوف لو الرسالة اللي بعدها كانت رد البوت، بيحذفها لأن الرد ده خلاص بقى مش مناسب بعد التعديل.
              if (index + 1 < _messages.length && _messages[index + 1]['role'] == 'bot') {
                setState(() {
                  _messages.removeAt(index + 1);
                });
              }

              await _saveMessages();

              Navigator.pop(context);

              // 🤖 نخلي البوت يرد على الرسالة المعدّلة
              await sendMessage(newText, isEdited: true);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }
  void _copyBotMessage(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم نسخ الرد إلى الحافظة'),
        duration: Duration(seconds: 2),
      ),
    );
  }


  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (value) {
          if (value == 'done' || value == 'notListening') {
            setState(() => _isListening = false);
            _speech.stop();
            // لو المستخدم وقف الكلام نرجع النص فاضي بعد التوقف
            if (_controller.text == '🎙️ جاري الاستماع...') {
              _controller.clear();
            }
          }
        },
        onError: (error) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ في مشكلة في الميكروفون: ${error.errorMsg}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _controller.text = '🎙️ جاري الاستماع...'; // ✅ يظهر النص أول ما يبدأ التسجيل
        });

        _speech.listen(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: 'ar_EG',
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
              setState(() {
                _controller.value = TextEditingValue(
                  text: val.recognizedWords,
                  selection: TextSelection.fromPosition(
                    TextPosition(offset: val.recognizedWords.length),
                  ),
                );
              });
            }
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 الميكروفون مش متاح دلوقتي، جرّب تاني.'),
          ),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _controller.clear(); // 🛑 لو ضغط تاني يوقف التسجيل ويفضي الحقل
    }
  }

  Future<void> _pickImage({required ImageSource source}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _messages.add({
          'role': 'user',
          'text': '',
          'imagePath': image.path,
        });
      });
      await _saveMessages();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('المساعد الطبي الذكي'),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.red,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("تأكيد الحذف"),
                  content: const Text("هل أنت متأكد إنك عايز تمسح سجل المحادثة بالكامل؟ 😢"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("إلغاء"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        "مسح",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              // لو المستخدم أكد الحذف
              if (confirm == true) {
                await MyPrefs.remove('chat_history');
                setState(() => _messages.clear());

                // رسالة بسيطة بعد الحذف
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم مسح سجل المحادثة بنجاح ✅"),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // listView
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    // لو المستخدم سحب لليمين مسافة كافية
                    if (details.delta.dx > 10 && !isUser) {
                      setState(() {
                        _replyToMessage = msg;
                      });

                    }
                  },
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: GestureDetector(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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
                        child:
                        msg.containsKey('imagePath')
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
                                _editMessageDialog(i, msg['text']!);
                              },
                              child:
                              Icon(Icons.edit, size: 15, color: Colors.white70),
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
                                onTap: () => _copyBotMessage(msg['text']!),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.copy, size: 16, color: Colors.grey),
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
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            // loading
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          if (_replyToMessage != null)
            Container(
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
                      _replyToMessage!['text']!.length > 60
                          ? '${_replyToMessage!['text']!.substring(0, 60)}...'
                          : _replyToMessage!['text']!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => setState(() => _replyToMessage = null),
                  ),
                ],
              ),
            ),

          // button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 5,
                    onEditingComplete: () {
                      if (_controller.text.isNotEmpty) {
                        sendMessage(_controller.text);
                        _controller.clear();
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
                        icon:
                        const Icon(Icons.camera_alt, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'camera') {
                            _pickImage(source: ImageSource.camera);
                          } else {
                            _pickImage(source: ImageSource.gallery);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'camera', child: Text('📸 الكاميرا')),
                          const PopupMenuItem(
                              value: 'gallery', child: Text('🖼️ المعرض')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: IconButton(
                        icon: Icon(
                          Icons.mic,
                          color: _isListening ? Colors.red : Colors.white,
                        ),
                        onPressed: _listen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            sendMessage(_controller.text);
                            _controller.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

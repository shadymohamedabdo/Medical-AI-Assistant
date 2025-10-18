import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // voice
  late stt.SpeechToText _speech;
  bool _isListening = false;

  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadMessages();
  }

  // load old message
  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('chat_history');
    if (saved != null) {
      final List decoded = jsonDecode(saved);
      setState(() {
        _messages.addAll(decoded.map((e) => Map<String, String>.from(e)));
      });

      // ✅ بعد ما يحمل الرسائل، ينزل لآخر رسالة
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    }
  }

  // save message when user Exited the application
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode(_messages));
  }

  // Conversation between user and ai
  Future<void> sendMessage(String message) async {
    setState(() {
      _messages.add({'role': 'user', 'text': message});
      _isLoading = true;
    });

    // ✅ ينزل لتحت بعد ما المستخدم يكتب
    _scrollToBottom();

    final reply = await _aiService.getBotReply(message, _messages);

    setState(() {
      _messages.add({'role': 'bot', 'text': reply});
      _isLoading = false;
    });

    // ✅ نحفظ بعد كل رسالة
    await _saveMessages();

    // ✅ بعد ما البوت يرد، ننزل لآخر الرسائل
    _scrollToBottom();
  }

  // 📍 دالة بتنزل لآخر الرسائل
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
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            _speech.stop();
          }
        },
        onError: (_) {},
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          listenFor: const Duration(seconds: 30), // أقصى مدة تسجيل
          pauseFor: const Duration(seconds: 3),   // يتوقف بعد سكوت 3 ثواني
          localeId: 'ar_EG', // اللغة المصرية/العربية
          onResult: (val) {
            if (val.recognizedWords.isNotEmpty) {
              _controller.value = TextEditingValue(
                text: val.recognizedWords,
                selection: TextSelection.fromPosition(
                  TextPosition(offset: val.recognizedWords.length),
                ),
              );
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('💉 المساعد التمريضي الذكي'),
        backgroundColor: Colors.teal,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('chat_history');
              setState(() => _messages.clear());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // ✅ ربط الكنترولر
              padding: const EdgeInsets.all(10),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
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
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        fontSize: 16,
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child:
                  TextField(
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
                      child: IconButton(
                        icon:  Icon(
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

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  final Dio _dio = Dio();

  static const String _apiKey = 'AIzaSyDIeKtCNszuHobjyeHyTJh6AUBkvnbMh5U'; // ← حط مفتاحك هنا
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  /// 🧠 دي الميثود اللي بتكلم Gemini مع الاحتفاظ بالسياق
  Future<String> getBotReply(
      String message, List<Map<String, String>> messagesHistory) async {
    try {
      // بناء المحادثة القديمة كلها علشان البوت يفهم السياق
      final conversation = messagesHistory.map((msg) {
        return {
          /// user = user question
          /// model = ai answer
          /// parts = text or message
          //[
          //   {
          //     "role": "user",
          //     "parts": [
          //       {"text": "إزاي أقيس الضغط؟"}
          //     ]
          //   },
          //   {
          //     "role": "model",
          //     "parts": [
          //       {"text": "بتقيس الضغط كذا وكذا..."}
          //     ]
          //   }
          // ]
          "role": msg['role'] == 'user' ? 'user' : 'model',
          "parts": [
            {"text": msg['text']}
          ]
        };
      }).toList();

      // ضيف الرسالة الجديدة في آخر المحادثة
      conversation.add({
        "role": "user",
        "parts": [
          {
            "text": '''
انت دلوقتي مساعد تمريضي ذكي اسمه "شادي".
رد بالعامية المصرية بأسلوب طبيعي ومهذب زي شات جي بي تي.
خلي إجاباتك تكون:
- دقيقة ومبنية على معلومات طبية وتمريضية صحيحة.
- فيها شرح مبسط وسهل الفهم لأي شخص.
- استخدم أمثلة من أرض الواقع وقت اللزوم.
- متجاوب مع سياق المحادثة ومكمل الكلام اللي قبل كده.
- لو السؤال عام أو خارج الطب والتمريض، رد برد لطيف وواضح، من غير ما تخرج عن دورك كمساعد تمريضي.
- حافظ على نغمة ودودة وإنسانية، وابدأ الردود أحيانًا بجمل طبيعية زي: "بُص يا سيدي"، "خليني أشرحلك"، "تمام، الموضوع بسيط".

السؤال: $message
'''
          }
        ]
      });

      final response = await _dio.post(
        _baseUrl,
        data: {"contents": conversation},
      );

      final reply =
      response.data['candidates'][0]['content']['parts'][0]['text'];

      return reply;
    } on DioException catch (e) {
      return 'حصل خطأ أثناء التواصل مع الذكاء الاصطناعي 😔 (رمز: ${e.response?.statusCode ?? 'غير معروف'})';
    } catch (e) {
      return 'حصل خطأ غير متوقع أثناء التواصل 😔';
    }
  }

  /// 💾 حفظ سجل الشات في SharedPreferences
  Future<void> saveChatHistory(List<Map<String, String>> messagesHistory) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_history', jsonEncode(messagesHistory));
  }

  /// 📖 تحميل سجل الشات من SharedPreferences
  Future<List<Map<String, String>>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chat_history');
    if (data != null) {
      return List<Map<String, String>>.from(jsonDecode(data));
    }
    return [];
  }
}

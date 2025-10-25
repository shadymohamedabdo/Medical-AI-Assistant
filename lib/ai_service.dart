import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:nursing_help/shared_pref.dart';

class AiService {
  final Dio _dio = Dio();

  static const String _apiKey =
      'AIzaSyDIeKtCNszuHobjyeHyTJh6AUBkvnbMh5U'; // ← مفتاحك
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  /// 🧠 إرسال الرسالة (نص أو صورة) إلى Gemini مع حفظ السياق
  Future<String> getBotReply(String message, List<Map<String, String>> messagesHistory) async {
    try {
      // 🧩 خُد آخر 6 رسائل بس من المحادثة (عشان السرعة)
      final recentMessages = messagesHistory.length > 6
          ? messagesHistory.sublist(messagesHistory.length - 6)
          : messagesHistory;
      // بناء المحادثة القديمه
      final conversation = recentMessages.map((msg) {
        // parts = to see it is text or image
        final parts = <Map<String, dynamic>>[];
        // لو الرسالة فيها نص
        if (msg['text'] != null && msg['text']!.isNotEmpty) {
          parts.add({"text": msg['text']});
        }

        // لو الرسالة فيها صورة
        if (msg.containsKey('imagePath')) {
          final imageBytes = File(msg['imagePath']!).readAsBytesSync();
          final base64Image = base64Encode(imageBytes);
          parts.add({
            "inline_data": {
              "mime_type": "image/jpeg",
              "data": base64Image,
            }
          });
        }
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
        return {
          "role": msg['role'] == 'user' ? 'user' : 'model',
          "parts": parts,
        };
      }).toList();

      // أضف آخر رسالة نصية للسؤال الحالي
      conversation.add({
        "role": "user",
        "parts": [
          {
            "text": '''
انت دلوقتي مساعد طبي ذكي اسمه "شادي".
رد بالعامية المصرية بأسلوب طبيعي ومهذب زي شات جي بي تي.
خلي إجاباتك تكون:
- دقيقة ومبنية على معلومات طبية وتمريضية صحيحة.
- فيها شرح مبسط ومختصر وسهل الفهم لأي شخص.
- استخدم أمثلة من أرض الواقع وقت اللزوم.
- متجاوب مع سياق المحادثة ومكمل الكلام اللي قبل كده.
- لو السؤال عام أو خارج الطب والتمريض، رد برد لطيف وواضح، من غير ما تخرج عن دورك كمساعد طبي.
- حافظ على نغمة ودودة وإنسانية، وابدأ الردود أحيانًا بجمل طبيعية زي: "بُص يا سيدي"،"بُص يا صاحبي"، "خليني أشرحلك"، "تمام، الموضوع بسيط".

السؤال: $message
'''
          }
        ]
      });

      final response = await _dio.post(
        _baseUrl,
        data: {"contents": conversation},
        options: Options(responseType: ResponseType.json),
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
        throw Exception("timeout"), // لو السيرفر اتأخر جدًا
      );


      final reply =
      response.data['candidates'][0]['content']['parts'][0]['text'];

      return reply.trim();
    }
    on DioException catch (e) {
      String errorMessage = 'حصل خطأ أثناء التواصل مع شادي 😔';

      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'الاتصال خد وقت طويل جدًا ⏳، تأكد إن النت شغال كويس وحاول تاني.';
      } else if (e.type == DioExceptionType.badResponse) {
        final status = e.response?.statusCode ?? 0;
        if (status >= 500) {
          errorMessage = 'الخدمة مش متاحة دلوقتي 🚧، جرب بعد شوية.';
        } else if (status == 404) {
          errorMessage = 'العنوان اللي بنحاول نوصله مش موجود (خطأ 404) ❌';
        } else if (status == 401 || status == 403) {
          errorMessage = 'في مشكلة في مفتاح الـ API 🔑، راجع الإعدادات.';
        } else {
          errorMessage = 'في مشكلة في الطلب اللي اتبعت 😕 (رمز: $status)';
        }
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'يبدو إن مفيش إنترنت 📴، اتأكد من الشبكة وجرب تاني.';
      } else if (e.type == DioExceptionType.cancel) {
        errorMessage = 'تم إلغاء العملية قبل ما تخلص ⚠️';
      }
      return errorMessage;
    } catch (e) {
      return 'حصل خطأ غير متوقع أثناء التواصل 😔، حاول تاني بعد شوية.';
    }

  }

  /// 💾 حفظ سجل المحادثة
  Future<void> saveChatHistory(List<Map<String, String>> messagesHistory) async {
    await MyPrefs.setString('chat_history', jsonEncode(messagesHistory));
  }

  /// 📖 تحميل سجل المحادثة
  Future<List<Map<String, String>>> loadChatHistory() async {
    final data = MyPrefs.getString('chat_history');
    if (data != null) {
      return List<Map<String, String>>.from(jsonDecode(data));
    }
    return [];
  }
}

# FAD Market — FCE AI Assistant — iOS patch

المصدر: APP_SOURCE04.zip، نسخة 1.0.8+51. جميع ملفات التطبيق أدناه منقولة حرفياً دون تعديل أي منطق.

## التركيب
خذ نسخة احتياطية. فك محتويات ZIP داخل جذر مشروع Flutter القديم (المجلد الذي يحتوي على pubspec.yaml)، وادمج المجلدات واختر Replace للملفات المتطابقة. لا تستبدل مجلد lib أو ios بالكامل ولا تفك الباتش داخل ios. المسارات تبدأ مباشرة بـ lib وassets وios، دون مجلد APP_SOURCE إضافي.

## الملفات التي ستُضاف أو تُستبدل (12)
- lib/widgets/ai_floating_button.dart — الأيقونة المتحركة ورسائلها.
- lib/screens/ai_maintenance_screen.dart — شاشة الشات، الصور، التسجيل وتشغيل الصوت، سجل المحادثات وحالة الرسائل.
- lib/services/ai_assistant_service.dart — API client للمساعد وموديلات الأجهزة والقطع والردود وإعدادات الميزة.
- lib/screens/home_screen.dart — إظهار الأيقونة وفتح المساعد والتحقق من تسجيل الدخول.
- assets/ai_assistant/fce_ai_frame_1.png
- assets/ai_assistant/fce_ai_frame_2.png
- assets/ai_assistant/fce_ai_frame_3.png
- assets/ai_assistant/fce_ai_frame_4.png
- assets/ai_assistant/fce_ai_frame_5.png
- assets/ai_assistant/fce_ai_frame_6.png
- pubspec.yaml — تعريف الأصول والحزم، ومنها image_picker وrecord وaudioplayers وpath_provider.
- ios/Runner/Info.plist — يتضمن NSCameraUsageDescription وNSMicrophoneUsageDescription وNSPhotoLibraryUsageDescription.

## بعد الاستبدال
من جذر مشروع Flutter:
```sh
flutter pub get
cd ios && pod install
```
افتح ios/Runner.xcworkspace في Xcode، وجرّب ظهور الأيقونة، دخول الشات، إرسال صورة من المعرض والكاميرا، وتسجيل الصوت وتشغيله على iPhone. بعدها أنشئ Archive بتوقيع Apple الخاص بك. هذا باتش سورس وليس ملف IPA جاهزاً للرفع.

## حدود التوافق
- لم تتوفر نسخة Apple القديمة للمقارنة. home_screen.dart وpubspec.yaml وInfo.plist ملفات مشتركة تُستبدل بالكامل؛ الباتش لا يدمج تخصيصاتك القديمة داخلها. احتفظ بأي تخصيصات مستقلة لديك قبل الاستبدال. لم أعدّل المنطق الموجود في المصدر، لكن لا يمكن ضمان عدم اختلافه عن نسختك القديمة.
- pubspec.yaml يحمل الإصدار 1.0.8+51 كما في المصدر؛ اضبط رقم البناء قبل الرفع إذا كان مستخدماً في App Store Connect.
- يعتمد المساعد على ملفات التطبيق الموجودة: app_controller.dart وmodels/customer.dart وservices/customer_session.dart وservices/api_service.dart، بما فيها authToken وgetOrCreateDeviceId وApiService.baseUrl. لم تُضمّن هذه الملفات العامة لتجنب استبدال منطق الحسابات والمتجر. بقية imports في الشاشة الرئيسية يجب أن تكون موجودة في سورس Apple.
- لا يوجد ملف موديلات/حالة إضافي خاص بالمساعد؛ الموديلات في ai_assistant_service.dart وحالة الشات في ai_maintenance_screen.dart.
- لم يُضمّن customer_chat_screen.dart لأنه شات العملاء المنفصل عن مساعد FCE.
- لم يُضمّن pubspec.lock؛ ملف المصدر يفرض Dart >=3.12.0 وFlutter >=3.44.0. الأمر flutter pub get يعيد حل الاعتماديات باستخدام pubspec.yaml وبيئتك؛ يلزم Flutter/Dart متوافق مع الحزم المحددة، ومنها record 6.2.1 وaudioplayers 6.6.0.
- إعداد iOS في المصدر هو 13.0. احتفظ بـPodfile وإعدادات التوقيع الموجودة لديك، وتأكد أن deployment target لا يقل عن 13.0. لم يُضمّن Podfile أو مشروع Xcode لأنهما لا يحتويان إعداد صلاحيات إضافياً خاصاً بهذه الميزة.
- يتطلب التشغيل وجود خدمات المساعد على السيرفر الحالي: ai_app_config.php وai_catalog.php وai_assistant.php وai_conversations.php تحت ApiService.baseUrl. لا يحتوي الباتش ملفات سيرفر أو داشبورد أو Android أو مفاتيح توقيع.
- التحقق المنفذ: مطابقة بايتات الملفات مع ZIP المصدر، سلامة ZIP، وجود imports المحلية والأصول في المصدر وصلاحيات iOS. لم يُنفذ build أو Archive لـiOS أو اختبار اتصال بالسيرفر.

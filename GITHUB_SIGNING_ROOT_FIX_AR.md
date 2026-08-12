# إصلاح جذري لمسار توقيع Android

تم توحيد المسار كالتالي:

- ملف المفتاح ينشأ في: `android/upload-keystore.jks`
- ملف الإعدادات ينشأ في: `android/key.properties`
- Gradle يقرأ المفتاح من جذر مشروع Android بواسطة `rootProject.file(...)`
- GitHub Actions يتحقق من وجود المفتاح ومن صحة كلمة المرور والـalias بواسطة `keytool` قبل بدء البناء.

لا توجد أي تعديلات على ملفات Dart أو تصميم التطبيق أو منطقه.

# بناء ملف AAB عبر GitHub Actions

## 1. إنشاء المستودع

1. أنشئ مستودع GitHub خاصًا Private.
2. ارفع محتويات هذا المشروع إلى جذر المستودع، بحيث يظهر ملف `pubspec.yaml` مباشرة في الصفحة الرئيسية.
3. لا ترفع `android/upload-keystore.jks` أو `android/key.properties` يدويًا.

## 2. إضافة أسرار التوقيع

من GitHub افتح:

`Settings > Secrets and variables > Actions > New repository secret`

وأضف الأسرار الأربعة التالية:

- `ANDROID_KEYSTORE_BASE64`: محتوى ملف التوقيع بعد تحويله إلى Base64.
- `ANDROID_KEY_ALIAS`: قيمة `keyAlias` من النسخة الخاصة لمفتاح التوقيع.
- `ANDROID_KEY_PASSWORD`: قيمة `keyPassword`.
- `ANDROID_STORE_PASSWORD`: قيمة `storePassword`.

يمكن تشغيل `tools/prepare_github_secrets_windows.ps1` على Windows من داخل مجلد النسخة الخاصة بالتوقيع لعرض القيم المطلوبة.

## 3. تشغيل البناء

1. افتح تبويب `Actions`.
2. اختر `Build signed Android App Bundle`.
3. اضغط `Run workflow`.
4. بعد نجاح البناء افتح التشغيل الأخير.
5. من قسم `Artifacts` حمّل `FAD-Market-AAB-v1.0.2-code45`.
6. فك الضغط وستجد `app-release.aab`.

## 4. النسخ القادمة

قبل كل تحديث عدّل رقم النسخة في `pubspec.yaml` مثل:

`version: 1.0.3+46`

يجب أن يكون الرقم بعد علامة `+` أكبر من كل رقم Version Code سبق رفعه إلى Google Play.

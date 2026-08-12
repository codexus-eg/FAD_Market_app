# قائمة رفع FAD Market إلى Google Play للمرة الأولى

## بيانات التطبيق

- App or game: App
- App name: FAD Market
- Default language: English (United States), ثم أضف العربية كلغة إضافية
- Free or paid: Free
- Category: Shopping
- Package name: fadmarket.app
- Version name: 1.0.2
- Version code: 45
- Target API: 36
- Contains ads: No، طالما لا توجد إعلانات أو SDK إعلاني في النسخة المنشورة
- Target audience: Adults / 18 and over؛ التطبيق مخصص لشراء معدات ومنتجات صناعية وليس للأطفال

## الملفات المرئية المطلوبة

- Store icon: `play_store_assets/app_icon_512.png`
- Feature graphic: PNG أو JPG بمقاس 1024×500
- Phone screenshots: جهّز على الأقل صورتين واضحتين من التطبيق، والأفضل 6–8 صور تشمل الرئيسية، المنتجات، تفاصيل المنتج، السلة، الطلبات، والشات

## App access

التطبيق يستخدم تسجيل الدخول وOTP. قبل الإرسال للمراجعة يجب إنشاء وصول دائم للمراجع لا يعتمد على رمز يتغير أو رقم يعمل في دولة واحدة. وفّر في Play Console تعليمات باللغة الإنجليزية وحسابًا تجريبيًا صالحًا دائمًا يفتح كل الوظائف المقيدة. إذا كانت شاشة الموظفين جزءًا من التطبيق المنشور، وفّر أيضًا بيانات موظف تجريبي.

## Data safety — مراجعة مبدئية من الكود

التطبيق يجمع أو يعالج البيانات التالية عند استخدام وظائفها:

- Personal info: الاسم، أرقام الهاتف، الدولة، المدينة، العنوان
- Precise location: الموقع الذي يختاره المستخدم، وهو اختياري
- Financial info: سجل الشراء وأرقام مراجع التحويل، وربما بيانات الدفع التي يعالجها مزود صفحة الدفع
- Messages: رسائل دعم العملاء
- Photos and files: مرفقات وصور الشات التي يرفعها المستخدم
- Device or other IDs: معرف جهاز ينشئه التطبيق لإدارة الجلسة وجهاز واحد

الأغراض الأساسية: App functionality، Account management، Fraud prevention/security، Customer support.

حدد Sharing = No فقط إذا كان أي مزود دفع أو OTP أو استضافة يعمل كمقدم خدمة بالنيابة عنك ولا يستخدم البيانات لأغراضه الخاصة. وإلا يجب التصريح بالمشاركة بدقة.

## متطلبات سياسة الخصوصية والحذف قبل Production

النسخة الحالية لا يظهر فيها رابط سياسة خصوصية داخل التطبيق ولا خيار حذف الحساب. قبل النشر العام يجب توفير:

1. سياسة خصوصية عامة على رابط HTTPS صالح وغير محمي بتسجيل دخول.
2. رابط السياسة داخل التطبيق وفي Play Console.
3. حذف الحساب والبيانات من داخل التطبيق.
4. صفحة ويب خارجية يستطيع المستخدم منها طلب حذف الحساب والبيانات.

يمكن رفع AAB للاختبار، لكن لا تعتبر هذه النقاط مكتملة للإنتاج حتى تنفيذها.

## اختبار الحساب الشخصي الجديد

إذا كان حساب المطور Personal وجديدًا، شغّل Closed testing مع 12 مختبرًا على الأقل، ويجب أن يظلوا منضمين 14 يومًا متتاليًا قبل طلب Production access.

## خطوات Play Console

1. Create app.
2. أكمل Store settings وMain store listing.
3. أكمل App content: Privacy policy, Ads, App access, Target audience, Content rating, Data safety, Government apps وأي إقرارات ظاهرة.
4. افتح Testing > Internal testing وارفع AAB أولًا لفحصه.
5. راجع Pre-launch report وأصلح أي Crash أو ANR.
6. أنشئ Closed testing عند الحاجة وأضف المختبرين.
7. بعد استيفاء الاختبار وسياسات البيانات، أنشئ Production release وأرسل للمراجعة.

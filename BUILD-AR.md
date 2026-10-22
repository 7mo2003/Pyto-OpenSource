# Pyto مفتوح المصدر — بناء نسخة كاملة من المصدر

هذا فرع مستقل من [المصدر الرسمي لـ Pyto](https://github.com/ColdGrub1384/Pyto)، أساسه commit `510cd710846e702437618d472dee439f855cb576`. رخصة MIT وحقوق المؤلف الأصلية محفوظة في `LICENSE`؛ وللتبعيات رخصها الخاصة.

لا يحتوي هذا الفرع على ملف IPA رفعه مستخدم، أو مكتبات محقونة مأخوذة منه، أو بيانات توقيع شخصية. لا ندّعي أنه إصدار رسمي أو مطابق لأي IPA سابق.

## الحالة الحالية: لا يوجد IPA جاهز

شُغّلت سبع محاولات فعلية على أجهزة macOS في GitHub Actions، ولم تصل أي منها إلى بناء التطبيق أو إنتاج IPA. [المحاولة الأخيرة وسجل التشخيص](https://github.com/7mo2003/Pyto-OpenSource/actions/runs/39694960478) تحتوي على artifact باسم `build-diagnostics` فقط، وليس تطبيقاً.

أُصلحت أخطاء إعداد وتوثيق وتنظيف، وتثبيت إصدارات أدوات Python، ومشكلة إخفاء أكواد فشل Clang وRust، ومسارات cryptography الشخصية القديمة، وتوافق CFFI وGensim وcppy. بقيت مشاكل توافق متعددة تتطلب عملاً على الاعتماديات الأصلية:

- SciPy: لم يعثر على إعداد BLAS/LAPACK صالح للبناء المتقاطع، مع توقف دعم Accelerate في هذه النسخة.
- lxml: عدم توافق رؤوس libxml2 مع libxslt (`opLimit` و`opCount`).
- Matplotlib: أخطاء أنواع مؤشرات في `ft2font.cpp`.
- pandas: تحذير متغير غير مستخدم يُعامل كخطأ.
- Pillow/libpng: غياب الرأس القديم `fp.h` في SDK الحديث.
- PyYAML: غياب `yaml.h` أثناء التجميع.

لذلك تفعيل الميزات موجود كتعديل مصدر قابل للمراجعة، وليس وعداً بأن جميع الميزات تعمل. لا يوجد إصدار موقّع، ولا اختبار على iPhone. تشغيل workflow مجدداً وحده لا يحل هذه العوائق؛ يلزم تحديث مسار بناء المكتبات القديمة والتحقق منها.

## الميزات

البناء عبر `build-ios.sh build` يمرر علم Swift المسمى `PYTO_OPEN_SOURCE` لتفعيل وضع النسخة الكاملة محلياً في هذا الفرع المرخص. هذا تعديل مصدر قابل للمراجعة، وليس حقن مكتبات أو تزوير إيصالات App Store. بدون العلم تبقى آلية الشراء الأصلية كما في المصدر الرسمي. نجاح تشغيل جميع الميزات يحتاج بناء واختباراً فعليين؛ لا توجد مطالبة بأنها اختُبرت على iPhone.

## البناء على GitHub

افتح تبويب **Actions** ثم مهمة **Build open-source iOS IPA** واضغط **Run workflow**. المهمة تستخدم جهاز GitHub يعمل بنظام macOS وXcode؛ لا تحتاج Mac محلياً.

إذا نجح البناء ستجد ضمن **Artifacts** ملف `Pyto-OpenSource-unsigned` وبداخله `Pyto-source-build-unsigned.ipa`. إذا فشل، ستجد سجلات التشخيص ضمن `build-diagnostics` بدلاً من IPA. المشروع وتبعياته قديمة؛ وجود workflow لا يضمن نجاح البناء مع Xcode الحديث.

**ملف IPA الناتج غير موقع**، ويحتاج توقيعاً وملف provisioning مناسبين قبل تثبيته على iPhone عادي. لا يتضمن هذا المستودع شهادة Apple أو أي وعد بتجاوز متطلبات iOS.

## البناء على Mac

يلزم Xcode الكامل مع iOS SDK، وHomebrew، وCocoaPods، وPython 3.10:

```bash
git clone https://github.com/7mo2003/Pyto-OpenSource.git
cd Pyto-OpenSource
bash build-ios.sh check
bash build-ios.sh prepare
bash build-ios.sh build
```

عملية `prepare` تنزّل التبعيات وsubmodules وتبني حزم Python؛ تحتاج مساحة كبيرة واتصالاً بالشبكة. أصلحنا مسار أرشيف Python، والتنزيلات المكررة، وترتيب submodules، وفك الأرشيفات غير التفاعلي، واكتشاف أخطاء HTTP. Linux وxtool لا يستطيعان بناء هذا المشروع الأصلي لأنه Xcode/CocoaPods وليس SwiftPM.

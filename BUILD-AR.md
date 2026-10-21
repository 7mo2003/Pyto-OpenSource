# Pyto مفتوح المصدر — بناء نسخة كاملة من المصدر

هذا فرع مستقل من [المصدر الرسمي لـ Pyto](https://github.com/ColdGrub1384/Pyto)، أساسه commit `510cd710846e702437618d472dee439f855cb576`. رخصة MIT وحقوق المؤلف الأصلية محفوظة في `LICENSE`؛ وللتبعيات رخصها الخاصة.

لا يحتوي هذا الفرع على ملف IPA رفعه مستخدم، أو مكتبات محقونة مأخوذة منه، أو بيانات توقيع شخصية. لا ندّعي أنه إصدار رسمي أو مطابق لأي IPA سابق.

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

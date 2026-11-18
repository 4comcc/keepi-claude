# كويك كيب (Flutter)

## أسرع طريقة للحصول على APK (بدون تثبيت أي شيء)
1. أنشئ مستودعاً جديداً على GitHub وارفع محتوى هذا المجلد إليه (فرع main).
2. افتح تبويب Actions وانتظر انتهاء "Build Android".
3. افتح التشغيل الناجح ونزّل `quick-keep-apk` من قسم Artifacts، فك الضغط وثبّت الملف.

الـ APK هنا موقّع بمفتاح debug، يصلح للتجربة والتثبيت اليدوي. أما `quick-keep-aab` فيحتاج توقيعاً بمفتاحك قبل رفعه إلى Google Play.

---
# كويك كيب (Flutter)

## التشغيل
```bash
flutter create --org com.egyptweb --project-name quick_keep .
# (لا يستبدل lib/main.dart ولا pubspec.yaml)
flutter pub get
flutter run
```

## Android: استقبال المشاركة
داخل `android/app/src/main/AndroidManifest.xml` في وسم `<activity>` أضف:
```xml
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="text/plain" />
</intent-filter>
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
</intent-filter>
```
وغيّر `android:launchMode` إلى `singleTask`.

## iOS: الصلاحيات (ios/Runner/Info.plist)
```xml
<key>NSPhotoLibraryUsageDescription</key><string>لحفظ الصور في التطبيق</string>
<key>NSCameraUsageDescription</key><string>لالتقاط الصور وحفظها</string>
<key>LSApplicationQueriesSchemes</key><array><string>https</string><string>http</string></array>
```
المشاركة من خارج التطبيق على iOS تحتاج Share Extension (اتبع دليل حزمة receive_sharing_intent).

## النشر
- Android: `flutter build appbundle --release` ثم رفع الملف إلى Google Play Console (يلزم توقيع keystore).
- iOS: `flutter build ipa --release` ثم الرفع عبر Xcode/Transporter إلى App Store Connect.
- غيّر applicationId / Bundle ID والأيقونة (`flutter_launcher_icons`) وسياسة الخصوصية قبل الرفع.

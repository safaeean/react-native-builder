# react-native-builder

ایمیج داکر آماده برای بیلد خروجی اندروید (APK/AAB) پروژه‌های React Native، مناسب استفاده به‌عنوان `image` در GitLab CI.

## چی داخلشه؟

- Java 17 (Eclipse Temurin)
- Node.js 20 + Yarn
- Android SDK command-line tools + platform-tools
- Android platform `android-34` و build-tools `34.0.0`
- Fastlane (اختیاری، برای امضا/انتشار خودکار)

## ساخت ایمیج

```bash
docker build -t react-native-builder .
```

می‌تونید نسخه‌ی پلتفرم/بیلدتولز اندروید رو هم عوض کنید:

```bash
docker build \
  --build-arg ANDROID_PLATFORM=android-35 \
  --build-arg ANDROID_BUILD_TOOLS=35.0.0 \
  -t react-native-builder .
```

## انتشار در GitLab Container Registry

این ریپو خودش یه `.gitlab-ci.yml` داره که با هر پوش، ایمیج رو می‌سازه و به رجیستری همین پروژه در گیت‌لب پوش می‌کنه (تگ `latest` روی برنچ پیش‌فرض). کافیه:

1. این ریپو رو در گیت‌لب خودتون (یا هر گیت‌لب دیگه) داشته باشید.
2. پایپ‌لاین اجرا بشه؛ ایمیج در آدرسی مثل زیر در دسترس قرار می‌گیره:
   ```
   registry.gitlab.com/<group>/<project>:latest
   ```

## استفاده در پروژه‌ی React Native خودتون

فایل `.gitlab-ci.example.yml` رو ببینید — نمونه‌ی کامل یه پایپ‌لاین است که با استفاده از این ایمیج، خروجی APK و AAB می‌گیره. کافیه اون رو به‌عنوان `.gitlab-ci.yml` داخل روت پروژه‌ی React Native خودتون کپی کنید و `image:` رو به آدرس ایمیجی که ساختید تغییر بدید.

نکات مهم:
- برای بیلد امضاشده (release قابل انتشار در Play Store) باید keystore و پسوردهاش رو به‌صورت CI/CD Variables (masked/protected) در گیت‌لب پروژه‌ی مقصد تعریف کنید و در `android/app/build.gradle` رفرنس بدید.
- کش `node_modules` و `.gradle` در نمونه فعاله تا بیلدهای بعدی سریع‌تر بشن.

## تست محلی

```bash
docker run --rm -it -v $(pwd):/project react-native-builder bash
cd /project/android && ./gradlew assembleRelease
```

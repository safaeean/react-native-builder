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

## انتشار خودکار ایمیج

این ریپو روی **GitHub** هست، پس انتشار ایمیج از طریق **GitHub Actions** به **GitHub Container Registry (GHCR)** انجام می‌شه — نه GitLab. با هر پوش به `main`/`master` یا هر تگ `v*`، ورک‌فلو `.github/workflows/docker-image.yml` ایمیج رو می‌سازه و در آدرس زیر پابلیش می‌کنه:

```
ghcr.io/safaeean/react-native-builder:latest
```

**نکته‌ی مهم:** پکیج‌های GHCR به‌صورت پیش‌فرض private هستن. برای اینکه هرکسی (مثلاً پایپ‌لاین GitLab یه پروژه‌ی دیگه) بتونه بدون لاگین ازش pull کنه، باید یک‌بار به‌صورت دستی پابلیکش کنی:

`github.com/<owner>/<repo>/pkgs/container/react-native-builder` → **Package settings** → **Change visibility** → **Public**

اگه ترجیح می‌دی همچنان به GitLab Container Registry هم پابلیش بشه (مثلاً چون تیمت روی GitLab CI کار می‌کنه)، فایل `.gitlab-ci.yml` این ریپو رو (که در ادامه توضیح داده می‌شه) هم می‌تونی فعال نگه داری — هر دو مسیر هم‌زمان قابل استفاده‌ست.

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

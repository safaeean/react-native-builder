# react-native-builder

ایمیج داکر آماده (پابلیک، روی GHCR) برای گرفتن خروجی Android از پروژه‌های React Native، داخل GitLab CI.

```
ghcr.io/safaeean/react-native-builder:latest
```

## سریع‌ترین راه استفاده

فایل `.gitlab-ci.yml` رو داخل روت پروژه‌ی React Native خودت با این محتوا بساز:

```yaml
image: ghcr.io/safaeean/react-native-builder:latest

stages:
  - build
  - release

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - android/.gradle/

build_apk:
  stage: build
  before_script:
    - npm ci
  script:
    - cd android
    - chmod +x ./gradlew
    - ./gradlew assembleRelease
  artifacts:
    paths:
      - android/app/build/outputs/apk/release/*.apk
    expire_in: 30 days

# --- از این‌جا به بعد فقط روی تگ اجرا می‌شه (اختیاری) ---

upload_apk_to_package_registry:
  stage: release
  needs: ["build_apk"]
  script:
    - |
      APK_PATH=$(find android/app/build/outputs/apk/release -name "*.apk" | head -n1)
      APK_NAME="app-${CI_COMMIT_TAG}.apk"
      curl --fail --header "JOB-TOKEN: ${CI_JOB_TOKEN}" \
        --upload-file "${APK_PATH}" \
        "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/android-builds/${CI_COMMIT_TAG}/${APK_NAME}"
  rules:
    - if: '$CI_COMMIT_TAG'

create_release:
  stage: release
  needs: ["upload_apk_to_package_registry"]
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  script:
    - echo "Creating release for $CI_COMMIT_TAG"
  release:
    tag_name: "$CI_COMMIT_TAG"
    description: "Release $CI_COMMIT_TAG"
    assets:
      links:
        - name: "app-${CI_COMMIT_TAG}.apk"
          url: "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/generic/android-builds/${CI_COMMIT_TAG}/app-${CI_COMMIT_TAG}.apk"
  rules:
    - if: '$CI_COMMIT_TAG'
```

بعد پوش کن روی گیت‌لب:

- روی هر پوش معمولی، جاب `build_apk` اجرا می‌شه و APK رو می‌تونی از **CI/CD → Jobs → build_apk → Browse** دانلود کنی.
- روی هر **تگ** (مثلاً `git tag v1.0.0 && git push origin v1.0.0`)، علاوه بر بیلد، APK به‌عنوان **GitLab Release** هم زیر **Deployments → Releases** پروژه‌ت منتشر می‌شه.

نیازی به نصب Android Studio، JDK یا SDK روی سیستم یا رانر خودت نیست — همه‌چیز داخل ایمیجه.

> اگه پروژه‌ت از Yarn استفاده می‌کنه (فایل `yarn.lock` داره، نه `package-lock.json`)، خط `npm ci` رو با `yarn install --frozen-lockfile` عوض کن.

---

## سوالات پرتکرار

### چطور APK امضاشده (برای انتشار در Play Store) بگیرم؟

۱. اگه keystore نداری بسازش:
```bash
keytool -genkeypair -v -storetype PKCS12 \
  -keystore release.keystore -alias my-key-alias \
  -keyalg RSA -keysize 2048 -validity 10000
```

۲. به‌صورت base64 دربیارش و در **Settings → CI/CD → Variables** پروژه‌ت (به‌صورت Masked + Protected) اضافه‌ش کن:
```bash
base64 -w0 release.keystore
```
متغیرها: `ANDROID_KEYSTORE_BASE64`, `MYAPP_UPLOAD_STORE_PASSWORD`, `MYAPP_UPLOAD_KEY_ALIAS`, `MYAPP_UPLOAD_KEY_PASSWORD`

۳. در `android/app/build.gradle`، بخش `signingConfigs.release` رو طوری تنظیم کن که از `System.getenv(...)` بخونه (نه از `gradle.properties`).

۴. در `.gitlab-ci.yml`، قبل از بیلد، keystore رو decode کن:
```yaml
before_script:
  - echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/release.keystore
  - npm ci
```

### چطور AAB (برای Play Store) بگیرم؟
به‌جای `assembleRelease` بنویس `bundleRelease` — خروجی توی `android/app/build/outputs/bundle/release/*.aab` قرار می‌گیره. نمونه‌ی جاب جدا برای AAB هم توی `.gitlab-ci.example.yml` هست.

### فقط روی برنچ خاصی بیلد بگیره؟
به جاب `build_apk` این رو اضافه کن:
```yaml
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

### بیلد کند شروع می‌شه یا خطای حافظه می‌ده؟
مطمئن شو رانر گیت‌لبت حداقل ۴ گیگ رم داره؛ Gradle برای بیلد اندروید به رم نیاز داره.

---

## این ایمیج چیه دقیقاً؟

- Java 17 (Eclipse Temurin)
- Node.js 22 + Yarn (npm از قبل با Node میاد)
- Android SDK command-line tools + platform-tools
- Android platform `android-34` و build-tools `34.0.0`
- Fastlane (اختیاری، برای امضا/انتشار خودکار)

ایمیج به‌صورت خودکار با هر پوش به `main` در همین ریپو، از طریق GitHub Actions ساخته و به GHCR پابلیش می‌شه (ورک‌فلو: `.github/workflows/docker-image.yml`).

## ساخت/تست محلی ایمیج (اختیاری)

فقط اگه می‌خوای خودت تغییرش بدی لازمه:

```bash
docker build -t react-native-builder .
docker run --rm -it -v $(pwd):/project react-native-builder bash
cd /project/android && ./gradlew assembleRelease
```

می‌تونی نسخه‌ی پلتفرم/بیلدتولز اندروید رو هم عوض کنی:
```bash
docker build \
  --build-arg ANDROID_PLATFORM=android-35 \
  --build-arg ANDROID_BUILD_TOOLS=35.0.0 \
  -t react-native-builder .
```

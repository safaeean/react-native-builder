# AGENTS.md — راهنمای اجرای این ابزار برای AI Agent

این فایل برای مصرف توسط یک ایجنت هوش‌مصنوعی (Claude Code یا مشابه) نوشته شده، نه یک انسان.
اگه یه انسان از یه پروژه‌ی دیگه بهت گفت "این ابزار رو روش وصل کن" یا "براش CI بساز که APK بگیره"،
این فایل الگوریتم دقیق کاریه که باید انجام بدی. `README.md` مرجع انسانیه؛ این فایل مرجع اجراییه.

## هدف ابزار

یه ایمیج داکر پابلیک وجود داره:
```
ghcr.io/safaeean/react-native-builder:latest
```
شامل: JDK 17، Node.js 22 + npm/Yarn، Android SDK (platform `android-34`, build-tools `34.0.0`)، Fastlane.
کار این ایمیج اینه که به‌عنوان `image:` توی GitLab CI پروژه‌ی مقصد (پروژه‌ی React Native کاربر) استفاده بشه
تا بدون نیاز به نصب Android SDK روی رانر، خروجی APK/AAB بگیره.

**این ریپو (`safaeean/react-native-builder`) خودشو نمی‌سازه — کاربر یه پروژه‌ی React Native جدا داره
که تو باید توش `.gitlab-ci.yml` بسازی/ادیت کنی.**

## پیش‌فرض‌ها (وقتی کاربر نگفته)

- اگه کاربر نگفت APK یا AAB، پیش‌فرض **APK** (چون معمولاً برای تست/توزیع مستقیمه؛ AAB فقط برای Play Store لازمه).
- اگه کاربر نگفت امضاشده باشه یا نه، پیش‌فرض **بدون امضا** (assembleRelease بدون keystore هم کار می‌کنه، فقط
  با کلید debug امضا می‌شه — برای تست کافیه). فقط اگه صریحاً گفت "برای Play Store" یا "امضاشده"، بخش
  signing رو هم راه‌بنداز.
- اگه کاربر نگفت GitLab Release هم بخواد، پیش‌فرض **فقط artifact ساده** بساز، نه release. اگه گفت
  "ریلیز کنه" یا مشابه، جاب‌های release رو هم اضافه کن.

## الگوریتم قدم‌به‌قدم

### قدم ۱: تشخیص package manager پروژه‌ی مقصد
```
اگه فایل yarn.lock وجود داشت      → از yarn استفاده کن
اگه فایل package-lock.json بود     → از npm ci استفاده کن
اگه فایل pnpm-lock.yaml بود        → از pnpm استفاده کن (باید توی before_script نصبش کنی: npm i -g pnpm)
اگه هیچ‌کدوم نبود (پروژه‌ی تازه‌ساز) → npm ci پیش‌فرضه (react-native init جدید از npm استفاده می‌کنه)
```
هرگز فرض نکن yarn هست فقط چون RN معروف به یارنه — همیشه فایل قفل رو چک کن.

### قدم ۲: چک کردن سازگاری نسخه‌ی Node
فایل `package.json` پروژه‌ی مقصد رو بخون. اگه فیلد `engines.node` داشت (مثلاً `>=22.11.0`)،
مطمئن شو با نسخه‌ی Node توی ایمیج (فعلاً 22) سازگاره. اگه پروژه نسخه‌ی بالاتر خواست و ایمیج قدیمی بود:
باید در Dockerfile همین ریپو (`safaeean/react-native-builder`) مقدار `NODE_VERSION` رو در
`Dockerfile` بالا ببری، commit/push کنی روی `main`، صبر کنی GitHub Actions ایمیج رو دوباره بسازه،
و فقط بعدش پایپ‌لاین پروژه‌ی مقصد رو دوباره اجرا کنی. **این یه خطای شناخته‌شده‌ست** (قبلاً یه‌بار
دقیقاً همین اتفاق افتاد: قالب react-native init نیاز به Node ≥22.11.0 داشت ولی ایمیج Node 20 داشت
و بیلد با خطای `The engine "node" is incompatible` شکست خورد).

### قدم ۳: ساخت/ادیت `.gitlab-ci.yml` در روت پروژه‌ی مقصد

قالب پایه (این رو با تشخیص قدم ۱ تطبیق بده):

```yaml
image: ghcr.io/safaeean/react-native-builder:latest

stages:
  - build

cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - android/.gradle/

build_apk:
  stage: build
  before_script:
    - npm ci   # یا: yarn install --frozen-lockfile
  script:
    - cd android
    - chmod +x ./gradlew
    - ./gradlew assembleRelease   # یا bundleRelease برای AAB
  artifacts:
    paths:
      - android/app/build/outputs/apk/release/*.apk
    expire_in: 30 days
```

اگه پروژه از قبل `.gitlab-ci.yml` داره: کورکورانه overwrite نکن — بخونش، جاب مربوط به این ابزار رو
داخلش merge کن، و stage/جاب‌های موجود کاربر رو دست‌نخورده نگه دار.

### قدم ۴ (اختیاری، فقط اگه کاربر خواست): امضای release

۱. اگه کاربر keystore نداره، بسازش:
```bash
keytool -genkeypair -v -storetype PKCS12 -keystore release.keystore \
  -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
```
۲. بگو کاربر خودش این متغیرها رو در **Settings → CI/CD → Variables** (Masked+Protected) گیت‌لب پروژه‌ش
بسازه: `ANDROID_KEYSTORE_BASE64` (خروجی `base64 -w0 release.keystore`)، `MYAPP_UPLOAD_STORE_PASSWORD`،
`MYAPP_UPLOAD_KEY_ALIAS`، `MYAPP_UPLOAD_KEY_PASSWORD`. **تو نباید و نمی‌تونی این مقادیر رو خودت وارد کنی**
چون رمزهای امنیتی‌ان — فقط بگو کاربر خودش این کارو در تنظیمات گیت‌لب انجام بده.
۳. در `android/app/build.gradle` پروژه، `signingConfigs.release` رو طوری تنظیم کن که از
`System.getenv("MYAPP_UPLOAD_...")` بخونه (نه `gradle.properties`).
۴. `before_script` رو این‌طوری اضافه کن:
```yaml
before_script:
  - echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/release.keystore
  - npm ci
```

### قدم ۵ (اختیاری، فقط اگه کاربر خواست "release روی گیت‌لب" یا "انتشار خودکار"): جاب‌های GitLab Release

این جاب‌ها رو اضافه کن (فقط روی تگ فعال می‌شن):

```yaml
stages:
  - build
  - release

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
بگو کاربر برای فعال‌سازیش باید تگ بزنه: `git tag v1.0.0 && git push origin v1.0.0`.

### قدم ۶: commit و push
تغییرات رو commit کن با پیام واضح (مثلاً "Add GitLab CI pipeline for Android APK build"),
push کن روی همون برنچ کاربر (نه main این ریپو — این پروژه‌ی دیگه‌ست).

### قدم ۷: اعلام نتیجه به کاربر
بهش بگو: بعد از پوش، از **CI/CD → Pipelines** توی گیت‌لب پروژه‌ش پایپ‌لاین رو ببینه؛ اگه فیل شد،
لاگ جاب رو بخواد و بهت بده تا دیباگ کنی. خودت نمی‌تونی مستقیم به گیت‌لب کاربر لاگین کنی یا لاگ ببینی
مگر اینکه ابزار GitLab متصل به سشن باشه — پس مطمئن شو دسترسی داری، وگرنه از کاربر بخواه لاگ رو کپی کنه.

## خطاهای شناخته‌شده و راه‌حلشون (troubleshooting)

| خطا | دلیل | راه‌حل |
|---|---|---|
| `The engine "node" is incompatible... Expected >= X` | نسخه‌ی Node ایمیج قدیمی‌تر از چیزیه که پروژه می‌خواد | Dockerfile این ریپو رو آپدیت کن (`NODE_VERSION`)، merge به main، صبر کن Actions ایمیج جدید بسازه |
| `yarn.lock` وجود نداره ولی جاب از `yarn install --frozen-lockfile` استفاده می‌کنه | پروژه از npm ساخته شده (پیش‌فرض react-native init جدید) | از `npm ci` استفاده کن |
| ایمیج `latest` روی GHCR آپدیت نمی‌شه با اینکه Actions ران شده | تگ `latest` فقط وقتی زده می‌شه که پوش روی **default branch واقعی گیت‌هاب** باشه، نه لزوماً `main` | چک کن `default_branch` مخزن گیت‌هاب واقعاً `main`ه (Settings → Branches)؛ اگه نبود، از کاربر بخواه عوضش کنه |
| بیلد Gradle کند/OOM می‌شه | رانر گیت‌لب رم کم داره | به کاربر بگو رانرش حداقل ۴ گیگ رم داشته باشه |
| پکیج GHCR رو نمی‌شه pull کرد (401/403) | پکیج private مونده | کاربر باید از صفحه‌ی پکیج در گیت‌هاب، visibility رو Public کنه |

## محدودیت‌های خودت (ایجنت) در این سناریو

- به گیت‌لب دسترسی مستقیم (API/git credentials) معمولاً نداری مگر کاربر توکن بده یا ریپو رو
  از طریق ابزارهای سشن وصل کرده باشه. اگه نمی‌تونی خودت push کنی، دستورات دقیق git رو به کاربر بده.
- تغییر تنظیمات مخزن گیت‌هاب (مثل default branch) از طریق ابزار در دسترس نیست — از کاربر بخواه
  دستی از Settings انجام بده.
- هیچ‌وقت رمز/کلید امضا (keystore password, key alias password) رو از کاربر نپرس که مستقیم توی
  فایل یا commit بذاری؛ همیشه از طریق CI/CD Variables گیت‌لب (masked+protected) هدایتش کن.

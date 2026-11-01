# انتشار نسخه جدید MYX-VPN

## یک‌بار برای همیشه: کلید امضای اندروید

اندروید فقط وقتی آپدیت را نصب می‌کند که **همه نسخه‌ها با یک کلید** امضا شده باشند. این کلید را یک بار بسازید و **هرگز گمش نکنید**. اگر گم شود، کاربران فعلی دیگر نمی‌توانند آپدیت بگیرند.

۱. ساخت کلید (به JDK نیاز دارد. `keytool` همراه Java نصب می‌شود):

```bash
keytool -genkeypair -v -keystore myx-release.jks -alias myx -keyalg RSA -keysize 4096 -validity 36500
```

۲. تبدیل به base64 (در PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("myx-release.jks")) | Set-Content keystore-base64.txt
```

۳. در گیتهاب بروید به **Settings → Secrets and variables → Actions → New repository secret** و این چهار مقدار را اضافه کنید:

| نام | مقدار |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | محتوای `keystore-base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | رمز keystore |
| `ANDROID_KEY_ALIAS` | `myx` |
| `ANDROID_KEY_PASSWORD` | رمز کلید (اگر جدا نگذاشتید، همان رمز keystore) |

از فایل `myx-release.jks` یک نسخه پشتیبان امن بگیرید و آن را داخل ریپو نگذارید (در `.gitignore` هست).

## هر بار که نسخه جدید می‌دهید

```bash
git tag -a v1.1.0 -m "متن تغییرات این نسخه"
git push origin v1.1.0
```

GitHub Actions خودش این کارها را انجام می‌دهد:
- `MYX-VPN-android-arm64.apk` و `MYX-VPN-android-armv7.apk`
- `MYX-VPN-windows-x64-setup.exe`
- `MYX-VPN-ios-unsigned.ipa` (امضا نشده، توضیحش پایین‌تر)
- `latest.json` (برای پیام آپدیت لازم است)

و همه را در یک Release منتشر می‌کند. متنی که بعد از `-m` می‌نویسید در پنجره آپدیت به کاربران نشان داده می‌شود.

## پیام آپدیت چطور کار می‌کند

اپ از آدرس `https://github.com/uhiygutfy/MYX-VPN/releases/latest/download/latest.json` شماره آخرین نسخه را می‌خواند. این بررسی ۸ ثانیه بعد از باز شدن اپ و بعد هر ۶ ساعت یک بار انجام می‌شود. اگر نسخه جدیدتری باشد:

- **اندروید:** فایل APK دانلود می‌شود و قبل از نصب این موارد بررسی می‌شود: SHA-256، نام پکیج، شماره نسخه، و اینکه با همان کلید شما امضا شده باشد. بعد نصب‌کننده اندروید باز می‌شود.
- **ویندوز:** نصب‌کننده دانلود و با SHA-256 بررسی می‌شود. بعد اجرا می‌شود و اپ بسته می‌شود.
- **iOS:** صفحه Release باز می‌شود.

کاربر می‌تواند «بعداً» را بزند. در این صورت پیام همان نسخه تا ۲۴ ساعت دوباره نشان داده نمی‌شود. آدرس ریپو در `lib/core/updater/update_config.dart` تعریف شده است.

## آیفون و آیپد

- اپ‌هایی که VPN دارند روی iOS فقط با **حساب پولی Apple Developer** (سالی ۹۹ دلار) و قابلیت Network Extension امضا می‌شوند. با حساب رایگان یا Sideloadly بخش VPN کار نمی‌کند.
- ساختن نسخه iOS به مک با Xcode نیاز دارد. CI روی مک گیتهاب یک نسخه امضا نشده می‌سازد.
- برای انتشار واقعی، در Xcode این کارها را انجام دهید:
  - Team خودتان را در `ios/Runner.xcodeproj` انتخاب کنید.
  - شناسه‌های `com.myx.vpn` و `com.myx.vpn.Tunnel` و App Group `group.com.myx.vpn` را در developer.apple.com بسازید.
  - از TestFlight یا App Store منتشر کنید.

## ویندوز

نسخه ویندوز سرویس `LanternSvc` را نصب می‌کند (هسته Lantern). اگر Lantern اصلی روی همان سیستم نصب است، اول آن را حذف کنید، چون هر دو از یک سرویس استفاده می‌کنند.

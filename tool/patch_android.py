"""يعدّل AndroidManifest.xml الذي ولّده flutter create.

المتغير KEEPI_VARIANT:
  base  = المشاركة + قائمة التحديد فقط (مثل الإصدار 8 الذي ثبّت على الهاتف)
  lite  = base + اختصارات الأيقونة + حفظ الحافظة/لقطة الشاشة + الأذونات (بدون زر الإعدادات السريعة)
  full  = lite + زر الإعدادات السريعة
"""
import os, re, sys, pathlib

VARIANT = os.environ.get("KEEPI_VARIANT", "full")
assert VARIANT in ("base", "lite", "full"), VARIANT
extras = VARIANT in ("lite", "full")
tile = VARIANT == "full"

path = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = path.read_text(encoding="utf-8")

if "android.intent.action.SEND" in s:
    print("already patched"); sys.exit(0)

filters = """
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
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="io.supabase.keepi" android:host="login-callback" />
            </intent-filter>
"""
shortcuts_meta = '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n' if extras else ""
# أول </activity> هو MainActivity
s = s.replace("</activity>", filters + shortcuts_meta + "        </activity>", 1)
s = s.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
s = re.sub(r'android:label="[^"]*"', 'android:label="Keepi"', s, count=1)

# استعلامات https لـ url_launcher
q = '\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>'
if "<queries>" in s:
    s = s.replace("<queries>", "<queries>" + q, 1)
else:
    s = s.replace("</manifest>", "    <queries>" + q + "\n    </queries>\n</manifest>")

# يجعل التطبيق مرئياً لتطبيقات مثل Keep و Gmail (رؤية الحزم في أندرويد 11+)
view_filter = """
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="https" />
                <data android:scheme="http" />
            </intent-filter>""" if extras else ""

save_activity = f"""
        <activity
            android:name=".SaveTextActivity"
            android:exported="true"
            android:icon="@mipmap/ic_launcher"
            android:label="Keepi"
            android:theme="@android:style/Theme.Translucent.NoTitleBar"
            android:excludeFromRecents="true"
            android:taskAffinity="">
            <intent-filter>
                <action android:name="android.intent.action.PROCESS_TEXT" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>{view_filter}
        </activity>
        <activity-alias
            android:name=".QuickShareAlias"
            android:targetActivity=".SaveTextActivity"
            android:exported="true"
            android:label="Keepi – حفظ سريع">
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
        </activity-alias>
"""

clip_parts = """
        <activity
            android:name=".ScreenshotSaveActivity"
            android:exported="true"
            android:label="Keepi – لقطة الشاشة"
            android:icon="@mipmap/ic_launcher"
            android:theme="@android:style/Theme.Translucent.NoTitleBar"
            android:excludeFromRecents="true"
            android:taskAffinity="" />
        <activity
            android:name=".ClipboardSaveActivity"
            android:exported="true"
            android:label="Keepi – حفظ الحافظة"
            android:icon="@mipmap/ic_launcher"
            android:theme="@android:style/Theme.Translucent.NoTitleBar"
            android:excludeFromRecents="true"
            android:taskAffinity="" />
""" if extras else ""

bubble_service = """
        <service
            android:name=".FloatingBubbleService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="floating quick-save bubble" />
        </service>
""" if extras else ""

tile_service = """
        <service
            android:name=".SaveClipTileService"
            android:exported="true"
            android:label="Keepi"
            android:icon="@drawable/ic_keepi_tile"
            android:permission="android.permission.BIND_QUICK_SETTINGS_TILE">
            <intent-filter>
                <action android:name="android.service.quicksettings.action.QS_TILE" />
            </intent-filter>
        </service>
""" if tile else ""

s = s.replace("</application>", save_activity + clip_parts + bubble_service + tile_service + "    </application>", 1)

if extras:
    perms = """    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

"""
    perms += """    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

"""
    s = s.replace("<application", perms + "    <application", 1)

if "android.permission.INTERNET" not in s:
    s = s.replace("<application", '    <uses-permission android:name="android.permission.INTERNET" />\n\n    <application', 1)

path.write_text(s, encoding="utf-8")
print("patched", VARIANT)

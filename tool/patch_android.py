"""يعدّل AndroidManifest.xml الذي ولّده flutter create: المشاركة، الاسم، الاستعلامات."""
import re, sys, pathlib

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
"""
# أول </activity> هو MainActivity
s = s.replace("</activity>", filters + '            <meta-data android:name="android.app.shortcuts" android:resource="@xml/shortcuts" />\n        </activity>', 1)
s = s.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
s = re.sub(r'android:label="[^"]*"', 'android:label="Keepi"', s, count=1)

# استعلامات https لـ url_launcher
if "<queries>" in s:
    s = s.replace("<queries>", '<queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>', 1)
else:
    s = s.replace("</manifest>", '    <queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>\n    </queries>\n</manifest>')

# نشاط "حفظ في كويك كيب" في قائمة تحديد النص
save_activity = """
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
            </intent-filter>
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
"""
s = s.replace("</application>", save_activity + clip_parts + "    </application>", 1)

perms = """    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />

"""
s = s.replace("<application", perms + "    <application", 1)

path.write_text(s, encoding="utf-8")
print("patched")

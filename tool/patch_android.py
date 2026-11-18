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
s = s.replace("</activity>", filters + "        </activity>", 1)
s = s.replace('android:launchMode="singleTop"', 'android:launchMode="singleTask"')
s = re.sub(r'android:label="[^"]*"', 'android:label="كويك كيب"', s, count=1)

# استعلامات https لـ url_launcher
if "<queries>" in s:
    s = s.replace("<queries>", '<queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>', 1)
else:
    s = s.replace("</manifest>", '    <queries>\n        <intent>\n            <action android:name="android.intent.action.VIEW" />\n            <data android:scheme="https" />\n        </intent>\n    </queries>\n</manifest>')

path.write_text(s, encoding="utf-8")
print("patched")

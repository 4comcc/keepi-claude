"""يجعل بناء release يُوقَّع بمفتاح ثابت (keepi-sideload.jks) فتتحدّث النسخ فوق بعضها."""
import glob, re, shutil, sys

shutil.copy("tool/keepi-sideload.jks", "android/app/keepi-sideload.jks")
path = glob.glob("android/app/build.gradle.kts")
if not path:
    sys.exit("build.gradle.kts not found")
path = path[0]
s = open(path, encoding="utf-8").read()

block = '''    signingConfigs {
        create("keepi") {
            storeFile = file("keepi-sideload.jks")
            storePassword = "keepi-sideload"
            keyAlias = "keepi"
            keyPassword = "keepi-sideload"
        }
    }

'''
if 'create("keepi")' not in s:
    assert re.search(r"^\s*buildTypes\s*\{", s, re.M), "buildTypes not found"
    s = re.sub(r"^(\s*)buildTypes\s*\{", block + r"\1buildTypes {", s, count=1, flags=re.M)

assert 'signingConfigs.getByName("debug")' in s, "debug signing line not found"
s = s.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("keepi")')
open(path, "w", encoding="utf-8").write(s)
print("signing patched")

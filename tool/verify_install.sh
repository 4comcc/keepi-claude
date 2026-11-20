#!/usr/bin/env bash
# يثبّت الـ APK على محاكي حقيقي ويطبع النتيجة وما يراه النظام عن التطبيق.
set +e
APK=${1:-app-release.apk}
echo "=== INSTALL ==="
adb install -r "$APK" 2>&1
echo "=== PACKAGE FLAGS ==="
adb shell pm list packages | grep quick_keep
echo "=== PROCESS_TEXT handlers (text/plain) ==="
adb shell cmd package query-activities --brief -a android.intent.action.PROCESS_TEXT -t text/plain 2>&1 | head -30
echo "=== VIEW https handlers (should include Keepi for visibility) ==="
adb shell cmd package query-activities --brief -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d https:// 2>&1 | head -30
echo "=== SEND text/plain handlers ==="
adb shell cmd package query-activities --brief -a android.intent.action.SEND -t text/plain 2>&1 | head -30
echo "=== DUMP (activities/services/shortcuts) ==="
adb shell dumpsys package com.egyptweb.quick_keep 2>&1 | grep -E "versionCode|Activity #|Service #|SaveText|ClipboardSave|ScreenshotSave|QuickShareAlias|SaveClipTile|shortcuts" | head -30
echo "=== LAUNCH SaveText via PROCESS_TEXT ==="
adb shell am start -a android.intent.action.PROCESS_TEXT -t text/plain -n com.egyptweb.quick_keep/.SaveTextActivity --es android.intent.extra.PROCESS_TEXT "keepi emulator test" 2>&1
sleep 3
adb shell run-as com.egyptweb.quick_keep cat shared_prefs/FlutterSharedPreferences.xml 2>&1 | head -5

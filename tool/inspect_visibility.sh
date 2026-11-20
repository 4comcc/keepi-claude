#!/usr/bin/env bash
# يثبّت كل نسخة ويطبع كيف يرى النظام ظهور الحزمة لتطبيقات أخرى (Gmail, Chrome...).
set +e
adb root >/dev/null 2>&1; sleep 2
for pair in "base:Keepi-base.apk" "lite:Keepi-lite.apk" "full:Keepi.apk"; do
  v=${pair%%:*}; f=${pair##*:}
  echo "################ VARIANT $v ($f)"
  adb uninstall com.egyptweb.quick_keep >/dev/null 2>&1
  adb install -r "$f" 2>&1 | tail -1
  echo "--- dumpsys package queries (size/lines)"
  adb shell dumpsys package queries > /tmp/q_$v.txt 2>&1
  wc -l /tmp/q_$v.txt
  head -25 /tmp/q_$v.txt
  echo "--- lines mentioning quick_keep"
  grep -n "quick_keep" /tmp/q_$v.txt | head -20
  echo "--- gmail lines"
  grep -n "com.google.android.gm" /tmp/q_$v.txt | head -10
done

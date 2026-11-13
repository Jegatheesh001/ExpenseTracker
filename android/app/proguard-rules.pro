# ProGuard / R8 rules for Expense Tracker

# Suppress missing class warnings from com.google.assistant.appactions:widgets / internal appactions_widgets
-dontwarn com.google.common.flogger.**
-dontwarn dalvik.system.VMStack
-dontwarn com.google.android.gms.internal.appactions_widgets.**

# Prevent Flutter plugins from being stripped
-keep class com.flutter.** { *; }
-keep class com.zhihu.matisse.** { *; }
-keep class com.tencent.** { *; }
-keep class top.kikt.** { *; }
-keep class com.luck.picture.lib.** { *; }

# Keep wechat_assets_picker and dependencies
-keep class com.wechat.** { *; }
-keep class com.github.herokings.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
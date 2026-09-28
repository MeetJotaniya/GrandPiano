# ─── Flutter embedding ────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# ─── just_audio / ExoPlayer ───────────────────────────────────────────────────
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.just_audio.**

# ─── ffmpeg_kit_flutter_new ───────────────────────────────────────────────────
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-keep class com.arthenica.smartexception.** { *; }
-dontwarn com.arthenica.smartexception.**

# ─── share_plus / FileProvider ────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**
-keep class androidx.core.content.FileProvider { *; }

# ─── Google Fonts ─────────────────────────────────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ─── Kotlin ───────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ─── General Android / OkHttp ────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

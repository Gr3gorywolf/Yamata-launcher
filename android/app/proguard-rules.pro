# Tink / ErrorProne fixes
-dontwarn com.google.errorprone.annotations.**
-keep class com.google.errorprone.annotations.** { *; }

# Tink (crypto)
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

-keep class net.sf.sevenzipjbinding.** { *; }
-keep interface net.sf.sevenzipjbinding.** { *; }

-keepclasseswithmembers class * {
    native <methods>;
}

-keepattributes *Annotation*

-keep class com.google.crypto.** { *; }
-keep class com.google.** { *; }

-dontwarn com.google.errorprone.**
-keep class com.google.errorprone.** { *; }

-keepclassmembers class * {
    public <init>(...);
}

-keep class io.flutter.** { *; }


-keep class * {
    *;
}

-dontwarn org.apache.commons.compress.**
-dontwarn org.tukaani.xz.**
-dontwarn org.brotli.**
-dontwarn com.github.luben.zstd.**
-dontwarn org.objectweb.asm.**
-dontwarn com.google.android.play.core.**
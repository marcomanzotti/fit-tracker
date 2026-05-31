# Keep kotlinx.serialization generated serializers
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class **$$serializer { *; }
-keep,includedescriptorclasses class com.marco.fittracker.**$$serializer { *; }
-keepclassmembers class com.marco.fittracker.** {
    *** Companion;
}
-keepclasseswithmembers class com.marco.fittracker.** {
    kotlinx.serialization.KSerializer serializer(...);
}

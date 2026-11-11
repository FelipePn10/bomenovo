# Regras do R8 (encolhimento de código do APK de release).
#
# O shared_preferences_android 2.5+ (Pigeon JNI) chama o código Kotlin do plugin direto do Dart
# via JNI, procurando classes e métodos pelo NOME e pela ASSINATURA, por exemplo:
#   getString(Ljava/lang/String;...;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;
# O R8 não enxerga essas chamadas e renomeava classes como kotlin.coroutines.Continuation
# (virava "t4"). A busca pelo método falhava e o app fechava logo ao abrir, porque o main()
# lê o SharedPreferences antes de desenhar a primeira tela.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }

# Classes do Kotlin usadas nas assinaturas acessadas pelo Dart
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.enums.EnumEntries { *; }
-keep class kotlin.jvm.internal.DefaultConstructorMarker { *; }

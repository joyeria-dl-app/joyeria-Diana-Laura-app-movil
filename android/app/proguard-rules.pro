# Reglas de R8 para el APK de release (#275). Flutter y los plugins de Firebase traen sus propias
# reglas (consumer rules) que conservan lo que el código nativo y el manifest llaman por nombre;
# aquí solo va lo que la app necesita además de ellas. Mientras menos -keep, más se ofusca.

# Play Core (componentes diferidos de Flutter): la app no los usa y no viene en el APK.
-dontwarn com.google.android.play.core.**

# Crashlytics: conserva archivo y número de línea para que los reportes se puedan leer
# (con el mapping.txt del build se recuperan los nombres originales).
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Android SDK, for Gradle builds and adb.
#
# Guarded on the SDK existing, so this is a no-op on machines without it.
if [[ -d "$HOME/Android/Sdk" ]]; then
  export ANDROID_HOME="$HOME/Android/Sdk"
  # Both names are still read by different tools; AGP prefers ANDROID_HOME,
  # older scripts and some CI actions still look for ANDROID_SDK_ROOT.
  export ANDROID_SDK_ROOT="$ANDROID_HOME"
  # PREPENDED so the SDK's own platform-tools wins over a distro `adb`. Debian
  # ships 34.x while the SDK here is 37.x; mixing an old adb with a new device
  # gives "adb server version doesn't match this client" and nothing works.
  path=("$ANDROID_HOME/platform-tools" "$ANDROID_HOME/cmdline-tools/latest/bin" $path)
fi

# Gradle resolves the JDK from JAVA_HOME before falling back to PATH, and the
# Android Gradle Plugin is version-sensitive — AGP 9 wants 17+. Pin it when the
# distro package is present rather than relying on whatever `java` resolves to.
if [[ -z "${JAVA_HOME:-}" ]]; then
  for _jdk in /usr/lib/jvm/java-21-openjdk-* /usr/lib/jvm/java-17-openjdk-*; do
    [[ -d "$_jdk" ]] && { export JAVA_HOME="$_jdk"; break }
  done
  unset _jdk
fi

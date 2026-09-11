#!/usr/bin/env bash
# Launches Fabric Loader's Knot launcher (client or server) against a dev
# classpath assembled by fabric_dev_launcher() in fabric.bzl - no installer,
# no `mods/` folder scanning, no Gradle/Loom.
#
# Args (all positional, injected by fabric.bzl - not meant to be typed by hand):
#   $1 loader_jar         fabric-loader-<version>.jar
#   $2 common_libs_dir    dir of fabric-loader's runtime deps (asm, sponge-mixin, ...)
#   $3 mc_libraries_dir   dir of the target Minecraft version's own libraries (gson, guava, ...)
#   $4 game_jar           the merged client+server jar (see minecraft_merged_jar.bzl)
#   $5 mods_dir           dir of mod jars (each with a fabric.mod.json at its root)
#   $6 main_class         net.fabricmc.loader.impl.launch.knot.Knot{Client,Server}
#   $7 run_dir            working directory to launch from (world save, logs, etc land here)
#   $8 side               "client" or "server"
#   $9 assets_dir         (client only, else "-") output of minecraft_assets()
#   $10 launch_info_json  (client only, else "-") output of minecraft_version()'s launch_info
#   -- everything after "--" is forwarded to Minecraft/the JVM as-is.
set -euo pipefail

loader_jar="$1"
common_libs_dir="$2"
mc_libraries_dir="$3"
game_jar="$4"
mods_dir="$5"
main_class="$6"
run_dir="$7"
side="$8"
assets_dir="$9"
launch_info_json="${10}"
shift 10

extra_args=()
if [ "${1:-}" = "--" ]; then
  shift
  extra_args=("$@")
fi

cp="$loader_jar"
for jar in "$common_libs_dir"/*.jar; do
  [ -e "$jar" ] && cp="$cp:$jar"
done
while IFS= read -r jar; do
  cp="$cp:$jar"
done < <(find "$mc_libraries_dir" -name '*.jar')
for jar in "$mods_dir"/*.jar; do
  [ -e "$jar" ] && cp="$cp:$jar"
done

mkdir -p "$run_dir"
cd "$run_dir"

# Dev convenience: auto-accept the Mojang EULA (https://aka.ms/MinecraftEULA)
# so `buck2 run` gets you straight to a running dev server instead of dying
# on first launch. Only touches this dev run dir, not anything real.
if [ ! -e eula.txt ]; then
  echo "eula=true" > eula.txt
fi

game_args=()
jvm_args=()
if [ "$side" = "client" ]; then
  version_id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$launch_info_json")
  asset_index_id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['asset_index_id'])" "$launch_info_json")
  game_args=(
    --username "DevPlayer"
    --version "$version_id"
    --gameDir "."
    --assetsDir "$assets_dir"
    --assetIndex "$asset_index_id"
    --uuid "00000000-0000-0000-0000-000000000000"
    --accessToken "0"
    --userType "legacy"
    --versionType "release"
  )
  # LWJGL natives + JNA/Unsafe usage trip JDK 24+'s native-access warnings;
  # silence them for a clean dev console.
  jvm_args=(--enable-native-access=ALL-UNNAMED)
  # SDL must initialize on macOS's first process thread. Mojang includes this
  # in the version manifest's macOS JVM arguments; invoke Java the same way.
  if [ "$(uname -s)" = "Darwin" ]; then
    jvm_args=(-XstartOnFirstThread "${jvm_args[@]}")
  fi
fi

echo "== fabric dev launcher ($side) ==" >&2
echo "main class: $main_class" >&2
echo "game jar:   $game_jar" >&2
echo "run dir:    $run_dir" >&2

exec java \
  "${jvm_args[@]}" \
  -Dfabric.development=true \
  -Dfabric.gameJarPath="$game_jar" \
  -cp "$cp" \
  "$main_class" \
  "${game_args[@]}" \
  "${extra_args[@]}"

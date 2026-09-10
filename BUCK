load("//minecraft_version.bzl", "minecraft_version")
load("//minecraft_assets.bzl", "minecraft_assets")
load("//minecraft_merged_jar.bzl", "minecraft_merged_jar")
load("//fabric.bzl", "fabric_api", "fabric_api_module", "fabric_loader")

export_file(
    name = "version_manifest_v2.json",
    src = "version_manifest_v2.json",
)

minecraft_version(
    name = "26.3-pre-3",
    version_manifest = ":version_manifest_v2.json",
    requested_version = "26.3-pre-3",
    visibility = ["PUBLIC"],
)

minecraft_assets(
    name = "26.3-pre-3-assets",
    minecraft_version = ":26.3-pre-3",
    visibility = ["PUBLIC"],
)

minecraft_merged_jar(
    name = "26.3-pre-3-merged",
    minecraft_version = ":26.3-pre-3",
    visibility = ["PUBLIC"],
)

fabric_loader(
    name = "fabric-loader",
    version = "0.19.5",
    sha1 = "ff9e65cffca4a67f31523e1807fe0855940fcbfa",
    visibility = ["PUBLIC"],
)

fabric_api(
    name = "fabric-api",
    version = "0.160.2+26.3",
    sha1 = "cab68347323dae750347aa5f18e404fefcbdf47b",
    visibility = ["PUBLIC"],
)

# These are nested inside fabric-api at runtime. Keep direct copies available
# to javac for mods that use interaction callbacks.
fabric_api_module(
    name = "fabric-api-base",
    artifact = "fabric-api-base",
    version = "2.0.6+fcdff87fa5",
    sha1 = "bd9944c06ce073bb9aecf6c08dd0e530af709f24",
    visibility = ["PUBLIC"],
)

fabric_api_module(
    name = "fabric-events-interaction-v0",
    artifact = "fabric-events-interaction-v0",
    version = "5.3.6+3434d6d9a5",
    sha1 = "e2443ff9b0fa12a3299be6a9a9d72f612c8df670",
    visibility = ["PUBLIC"],
)

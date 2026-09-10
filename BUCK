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

fabric_api_module(
    name = "fabric-networking-api-v1",
    artifact = "fabric-networking-api-v1",
    version = "6.3.8+fcdff87fa5",
    sha1 = "0ae89224c57b35c5fe8fb63bd18a2b170557e2ff",
    visibility = ["PUBLIC"],
)

fabric_api_module(
    name = "fabric-lifecycle-events-v1",
    artifact = "fabric-lifecycle-events-v1",
    version = "4.1.9+ffef5f67a5",
    sha1 = "15e52b6b49b76f5c3948f224ea934dc4600ebbea",
    visibility = ["PUBLIC"],
)

fabric_api_module(
    name = "fabric-rendering-v1",
    artifact = "fabric-rendering-v1",
    version = "27.0.13+fdb9bf40a5",
    sha1 = "18572c75f3c19d0189483e1c10596909dd7f9fde",
    visibility = ["PUBLIC"],
)

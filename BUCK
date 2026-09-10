load("//minecraft_version.bzl", "minecraft_version")
load("//minecraft_assets.bzl", "minecraft_assets")
load("//minecraft_merged_jar.bzl", "minecraft_merged_jar")
load("//fabric.bzl", "fabric_loader")

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

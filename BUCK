load("//minecraft_version.bzl", "minecraft_version")
load("//minecraft_assets.bzl", "minecraft_assets")

export_file(
    name = "version_manifest_v2.json",
    src = "version_manifest_v2.json",
)

minecraft_version(
    name = "1.21.5",
    version_manifest = ":version_manifest_v2.json",
    requested_version = "1.21.5",
)

minecraft_assets(
    name = "1.21.5-assets",
    minecraft_version = ":1.21.5",
)

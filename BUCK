load("//minecraft_version.bzl", "minecraft_version")
load("//minecraft_assets.bzl", "minecraft_assets")

http_file(
    name = "version_manifest_v2.json",
    urls = ["https://launchermeta.mojang.com/mc/game/version_manifest_v2.json"],
    sha256 = "4be002d7b7946dcacb15b72cf251ae08ac8cac409dc852174b01fb0ce35ea0d4",
)

minecraft_version(
    name = "1.21.4",
    version_manifest = ":version_manifest_v2.json",
    requested_version = "1.21.4",
)

minecraft_assets(
    name = "1.21.4-assets",
    minecraft_version = ":1.21.4",
)

load("//minecraft_info.bzl", "MinecraftInfo")

# Mojang's version.json only ever lists a single "natives-linux" classifier
# for LWJGL, which is x86_64-only. LWJGL itself does publish arm64 (and
# arm32/ppc64le/riscv64) Linux natives, on Maven Central - Mojang's launcher
# just doesn't know about them yet. On an aarch64 host, swap in the upstream
# arm64 natives jar instead so the client actually starts. This is the same
# trick tools like portable-mc's "LWJGL fix" do.
_LWJGL_LINUX_ARM64_SHA1 = {
    # "lwjgl-<module>" -> sha1 of lwjgl-<module>-3.4.3-natives-linux-arm64.jar on Maven Central
    "lwjgl": "101c753b129dbdeed565798d259b2b9544ef3878",
    "lwjgl-freetype": "6babd5ddf9b4850e91a952d494cfd22b895ce200",
    "lwjgl-jemalloc": "b558d38d8eaa32831bb66835aae163428fe69646",
    "lwjgl-openal": "f2083556a7d8a02e4abeb2b933642250ef06c61d",
    "lwjgl-opengl": "84f229d793388be57ae5555b0cfee09b5990fa20",
    "lwjgl-sdl": "577e41b6d0006f3d3f841c14abe19736e695a760",
    "lwjgl-shaderc": "f17eb9b12086809a31e61734dabc1dea80f6b7b2",
    "lwjgl-spvc": "85d2636eb1368a3864fb10faec02a4269020b31e",
    "lwjgl-stb": "74f1cd22ccf4fd7432b982372b8a34c93cd9aacf",
    "lwjgl-vma": "0a9e20e7d8ae4d0106cd23ae58a1b72ca151c49f",
}

def _is_host_linux_arm64() -> bool:
    return host_info().os.is_linux and host_info().arch.is_aarch64

def _lwjgl_linux_arm64_fixup(lib_name: str, url: str, sha1: str) -> (str, str):
    # lib_name looks like "org/lwjgl/lwjgl-opengl/3.4.3/lwjgl-opengl-3.4.3-natives-linux.jar"
    if not lib_name.startswith("org/lwjgl/") or not lib_name.endswith("-natives-linux.jar"):
        return url, sha1
    file_name = lib_name.split("/")[-1]  # "lwjgl-opengl-3.4.3-natives-linux.jar"
    module = file_name.split("-natives-linux.jar")[0].rsplit("-", 1)[0]  # "lwjgl-opengl"
    fixed_sha1 = _LWJGL_LINUX_ARM64_SHA1.get(module)
    if not fixed_sha1:
        return url, sha1
    fixed_url = "https://repo1.maven.org/maven2/" + lib_name.replace("-natives-linux.jar", "-natives-linux-arm64.jar")
    return fixed_url, fixed_sha1

def _library_rules_match(rules):
    for rule in rules:
        # Assert action is always "allow"? That's the only thing appearing in the json
        os_name = rule["os"]["name"]
        # FIXME: Non-linux platform support
        if os_name != "linux":
            return False
    return True


def _minecraft_version_impl(ctx: AnalysisContext) -> list[Provider]:
    # Convert from dependency to artifact
    # TODO: Should this assert only one output?
    version_manifest = ctx.attrs.version_manifest[DefaultInfo].default_outputs[0]
    requested_version = ctx.attrs.requested_version

    # Get version json
    version_json_artifact = ctx.actions.declare_output(requested_version + ".json", has_content_based_path = False)
    def derive_version_json(ctx: AnalysisContext, dynamic_artifacts, outputs):
        # Read the version manifest and download the version.json we desired
        manifest_json = dynamic_artifacts[version_manifest].read_json()
        for version in manifest_json["versions"]:
            if version["id"] == requested_version:
                ctx.actions.download_file(
                    outputs[version_json_artifact].as_output(),
                    version["url"],
                    sha1=version["sha1"],
                )
                break
    ctx.actions.dynamic_output(
        dynamic=[version_manifest],
        inputs=[],
        outputs=[version_json_artifact.as_output()],
        f=derive_version_json
    )

    # Crawl version json and get the asset index, jars, mappings, and libs
    asset_index_artifact = ctx.actions.declare_output("asset_index.json", has_content_based_path = False)
    client_jar_artifact = ctx.actions.declare_output("client.jar", has_content_based_path = False)
    server_jar_artifact = ctx.actions.declare_output("server.jar", has_content_based_path = False)
    libraries_dir_artifact = ctx.actions.declare_output("libraries", dir = True)
    # Same jars as libraries_dir_artifact, but symlinked in one flat directory
    # keyed by basename instead of their full maven path ("com/mojang/...").
    # A directory of nested subdirectories doesn't work as a javac/java `-cp
    # <dir>/*` wildcard entry (that only picks up jars directly inside the
    # given directory) - this flat layout does, so java_library.bzl's
    # `prebuilt_jar_dirs` can use it as Minecraft's own compile-time classpath
    # (DataFixerUpper, fastutil, ...) without needing to enumerate every jar
    # by name (the exact set/versions vary release to release).
    libraries_flat_dir_artifact = ctx.actions.declare_output("libraries_flat", dir = True)
    launch_info_artifact = ctx.actions.declare_output("launch_info.json", has_content_based_path = False)

    def derive_version_json_contents(ctx: AnalysisContext, dynamic_artifacts, outputs):
        version_json = dynamic_artifacts[version_json_artifact].read_json()
        ctx.actions.download_file(
            outputs[asset_index_artifact].as_output(),
            version_json["assetIndex"]["url"],
            sha1=version_json["assetIndex"]["sha1"],
        )
        ctx.actions.download_file(
            outputs[client_jar_artifact].as_output(),
            version_json["downloads"]["client"]["url"],
            sha1=version_json["downloads"]["client"]["sha1"],
        )
        ctx.actions.download_file(
            outputs[server_jar_artifact].as_output(),
            version_json["downloads"]["server"]["url"],
            sha1=version_json["downloads"]["server"]["sha1"],
        )
        fixup_lwjgl = _is_host_linux_arm64()
        libraries = {}
        for library in version_json["libraries"]:
            if not _library_rules_match(library.get("rules", [])):
                continue
            lib_name = library["downloads"]["artifact"]["path"]
            url = library["downloads"]["artifact"]["url"]
            sha1 = library["downloads"]["artifact"]["sha1"]
            if fixup_lwjgl:
                url, sha1 = _lwjgl_linux_arm64_fixup(lib_name, url, sha1)
            libraries[lib_name] = ctx.actions.download_file(
                ctx.actions.declare_output(lib_name, has_content_based_path = False).as_output(),
                url,
                sha1=sha1,
            )
        ctx.actions.symlinked_dir(outputs[libraries_dir_artifact].as_output(), libraries)
        libraries_flat = {}
        for lib_name, artifact in libraries.items():
            libraries_flat[lib_name.split("/")[-1]] = artifact
        ctx.actions.symlinked_dir(outputs[libraries_flat_dir_artifact].as_output(), libraries_flat)

        # A tiny sidecar with the bits of version.json that things like a
        # client dev launcher need but that aren't otherwise materialized as
        # artifacts (e.g. the --version/--assetIndex values a vanilla/Fabric
        # client expects on its command line).
        ctx.actions.write(
            outputs[launch_info_artifact].as_output(),
            json.encode({
                "id": version_json["id"],
                "asset_index_id": version_json["assetIndex"]["id"],
            }),
        )
    ctx.actions.dynamic_output(
        dynamic=[version_json_artifact],
        inputs=[],
        outputs=[
            client_jar_artifact.as_output(),
            server_jar_artifact.as_output(),
            asset_index_artifact.as_output(),
            libraries_dir_artifact.as_output(),
            libraries_flat_dir_artifact.as_output(),
            launch_info_artifact.as_output(),
        ],
        f=derive_version_json_contents,
    )
    return [
        DefaultInfo(
            default_outputs=[client_jar_artifact, server_jar_artifact],
            sub_targets={
                "asset_index":  [DefaultInfo(default_output=asset_index_artifact)],
                "libraries": [DefaultInfo(default_output=libraries_dir_artifact)],
                "libraries_flat": [DefaultInfo(default_output=libraries_flat_dir_artifact)],
            },
        ),
        MinecraftInfo(
            version_json=version_json_artifact,
            client_jar=client_jar_artifact,
            server_jar=server_jar_artifact,
            asset_index=asset_index_artifact,
            libraries_dir=libraries_dir_artifact,
            launch_info=launch_info_artifact,
        ),
    ]

minecraft_version = rule(
    doc = "Given version manifest and a requested version, produces the Minecraft jars as output and a MinecraftInfo provider with all other useful artifacts from the version json",
    impl = _minecraft_version_impl,
    attrs = {
        "version_manifest": attrs.dep(doc = "Dependency whose only output is the version_manifest_v2.json available from Mojang's api"),
        "requested_version": attrs.string(doc = "The requested Minecraft version, as it appears in version_manifest_v2.json"),
    }
)

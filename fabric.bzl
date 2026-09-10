load("//java_library.bzl", "JavaLibraryInfo", "java_library")

def _fabric_loader_impl(ctx: AnalysisContext) -> list[Provider]:
    jar = ctx.actions.declare_output("fabric-loader-{}.jar".format(ctx.attrs.version), has_content_based_path = False)
    ctx.actions.download_file(
        jar.as_output(),
        "https://maven.fabricmc.net/net/fabricmc/fabric-loader/{v}/fabric-loader-{v}.jar".format(v = ctx.attrs.version),
        sha1 = ctx.attrs.sha1,
        has_content_based_path = False,
    )
    return [
        DefaultInfo(default_output = jar),
        JavaLibraryInfo(jar = jar, classpath = [jar]),
    ]

fabric_loader = rule(
    doc = "Downloads a Fabric Loader release jar from the Fabric maven. Useful as a compile-time dependency for mod entrypoints (`net.fabricmc.api.*`) and, at runtime, as the thing that actually loads/launches mods.",
    impl = _fabric_loader_impl,
    attrs = {
        "sha1": attrs.string(doc = "sha1 of fabric-loader-<version>.jar, from https://maven.fabricmc.net/net/fabricmc/fabric-loader/<version>/fabric-loader-<version>.jar.sha1"),
        "version": attrs.string(),
    },
)

def fabric_mod(
        name,
        srcs = [],
        resources = [],
        fabric_mod_json = None,
        deps = [],
        compile_only_deps = [],
        java_version = "21",
        visibility = None):
    """A Fabric mod: java_library()'s srcs/resources plumbing, plus fabric.mod.json,
    packaged as a jar ready to drop in a `mods/` folder.

    `deps` are compiled against *and* bundled onto the runtime classpath info
    (transitively, via JavaLibraryInfo) - e.g. other fabric_mod()/java_library()
    code this mod needs at runtime that isn't provided by the loader/game itself.

    `compile_only_deps` (e.g. a minecraft_merged_jar() or fabric_loader()) are
    only used to build the classpath for javac; they are not bundled into the
    output jar since Fabric Loader supplies the game + itself at runtime.
    """
    resource_map = {}
    if fabric_mod_json:
        resource_map["fabric.mod.json"] = fabric_mod_json

    java_library(
        name = name,
        srcs = srcs,
        resources = resources,
        resource_map = resource_map,
        deps = deps,
        prebuilt_jars = [d for dep in compile_only_deps for d in _classpath_only(dep)],
        java_version = java_version,
        visibility = visibility,
    )

def _classpath_only(dep):
    # fabric_mod's compile_only_deps are plain deps at the macro layer (we
    # don't have access to providers here, only at analysis time), so we just
    # forward them through prebuilt_jars, which accepts attrs.source() -
    # i.e. deps whose DefaultInfo output is a jar. minecraft_merged_jar() and
    # fabric_loader() both qualify.
    return [dep]

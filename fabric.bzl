load("//java_library.bzl", "JavaLibraryInfo", "java_library")
load("//minecraft_info.bzl", "MinecraftInfo")

# fabric-loader ships as a slim jar plus a small, fixed set of runtime
# dependencies (ASM + Sponge Mixin, plus MixinExtras in dev). These are
# published per-loader-version as Gradle Module Metadata
# (fabric-loader-<version>.json on the Fabric maven, under "libraries"). The
# defaults below are that metadata's "common" + "development" library sets
# for fabric-loader 0.19.5 - if you bump the loader version, re-derive these
# from that version's .json.
_FABRIC_LOADER_0_19_5_LIBRARIES = [
    # (maven coordinate, sha1)
    ("org.ow2.asm:asm:9.10.1", "ada2141c0cc52ee8f5c48cd5fa4ce0e794f22236"),
    ("org.ow2.asm:asm-analysis:9.10.1", "8d49f14d51f632cb1d87c88d1ceaf50db0d8af1b"),
    ("org.ow2.asm:asm-commons:9.10.1", "4229e4c55fd8e01c23f9fe9884075cc628aacc50"),
    ("org.ow2.asm:asm-tree:9.10.1", "e244332a17564c1d1572449399a842de35881be2"),
    ("org.ow2.asm:asm-util:9.10.1", "7bb9d450e8d4cbf9f9e04096c44bbfe7fba80b15"),
    ("net.fabricmc:sponge-mixin:0.17.4+mixin.0.8.7", "5f66cc9f59b8efaa942155a3d5a30599bf6640dd"),
    ("io.github.llamalad7:mixinextras-fabric:0.5.5", "d1055b99c0ab08a8403fe2da3d79ca28e6340a76"),
]

def _maven_jar_url_and_name(coord: str) -> (str, str):
    group, artifact, version = coord.split(":")
    file_name = "{a}-{v}.jar".format(a = artifact, v = version)
    path = "{g}/{a}/{v}/{f}".format(g = group.replace(".", "/"), a = artifact, v = version, f = file_name)
    return "https://maven.fabricmc.net/" + path, file_name

FabricLoaderInfo = provider(
    doc = "Split-out view of a fabric_loader() target: the loader jar on its own, plus its runtime dependency jars (ASM, Sponge Mixin, ...), for callers (like fabric_dev_launcher()) that need to treat them differently.",
    fields = ["loader_jar", "common_libraries"],
)

def _fabric_loader_impl(ctx: AnalysisContext) -> list[Provider]:
    jar = ctx.actions.declare_output("fabric-loader-{}.jar".format(ctx.attrs.version), has_content_based_path = False)
    ctx.actions.download_file(
        jar.as_output(),
        "https://maven.fabricmc.net/net/fabricmc/fabric-loader/{v}/fabric-loader-{v}.jar".format(v = ctx.attrs.version),
        sha1 = ctx.attrs.sha1,
        has_content_based_path = False,
    )

    common_libraries = []
    for coord, sha1 in ctx.attrs.common_libraries:
        url, file_name = _maven_jar_url_and_name(coord)
        lib_jar = ctx.actions.declare_output("libs/" + file_name, has_content_based_path = False)
        ctx.actions.download_file(lib_jar.as_output(), url, sha1 = sha1, has_content_based_path = False)
        common_libraries.append(lib_jar)

    return [
        DefaultInfo(default_output = jar, sub_targets = {
            "libs": [DefaultInfo(default_outputs = common_libraries)],
        }),
        JavaLibraryInfo(jar = jar, classpath = [jar] + common_libraries),
        FabricLoaderInfo(loader_jar = jar, common_libraries = common_libraries),
    ]

fabric_loader = rule(
    doc = "Downloads a Fabric Loader release jar (plus its runtime deps: ASM, Sponge Mixin, ...) from the Fabric maven. Useful as a compile-time dependency for mod entrypoints (`net.fabricmc.api.*`) and, at runtime, as the thing that actually loads/launches mods - see fabric_dev_launcher().",
    impl = _fabric_loader_impl,
    attrs = {
        "common_libraries": attrs.list(
            attrs.tuple(attrs.string(), attrs.string()),
            default = _FABRIC_LOADER_0_19_5_LIBRARIES,
            doc = "List of (maven coordinate, sha1) for fabric-loader's own runtime deps. Defaults match fabric-loader 0.19.5's published Gradle Module Metadata; override if you use a different loader version.",
        ),
        "sha1": attrs.string(doc = "sha1 of fabric-loader-<version>.jar, from https://maven.fabricmc.net/net/fabricmc/fabric-loader/<version>/fabric-loader-<version>.jar.sha1"),
        "version": attrs.string(),
    },
)

def fabric_mod(
        name,
        srcs = [],
        resources = [],
        fabric_mod_json = None,
        mixin_configs = {},
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

    `mixin_configs` is a dict of {jar-root dest path: source} for Mixin config
    JSON files (e.g. {"examplemod.mixins.json": "src/main/resources/examplemod.mixins.json"}).
    You still need to list each one under fabric.mod.json's top-level "mixins"
    array yourself - Fabric Loader reads that to know which configs to apply;
    this just gets the file packaged at the right place in the jar. Sponge
    Mixin + ASM + MixinExtras are already on the compile/runtime classpath
    transitively via fabric_loader (see compile_only_deps), no extra wiring
    needed for @Mixin classes to compile or run. Mixin's annotation processor
    (refmap generation) is intentionally not wired up here - it's only needed
    when mixin targets are remapped/obfuscated, which they aren't in this
    repo's unobfuscated snapshot; mixin target class/method names are just
    the real Mojang-mapped names.
    """
    resource_map = dict(mixin_configs)
    if fabric_mod_json:
        resource_map["fabric.mod.json"] = fabric_mod_json

    java_library(
        name = name,
        srcs = srcs,
        resources = resources,
        resource_map = resource_map,
        # compile_only_deps go through `deps`, not `prebuilt_jars`: java_library's
        # output jar is only ever packaged from *this* rule's own srcs/resources,
        # never from deps' jars, so routing them through `deps` still gets us
        # "compile classpath only, nothing bundled" - and, unlike prebuilt_jars
        # (a flat attrs.source list), `deps` pulls in each dep's *transitive*
        # JavaLibraryInfo.classpath too. That matters here: fabric_loader()'s
        # own classpath includes its runtime deps (Sponge Mixin, ASM,
        # MixinExtras), which @Mixin-annotated mod code needs to compile against.
        deps = deps + compile_only_deps,
        java_version = java_version,
        visibility = visibility,
    )

def _fabric_dev_launcher_impl(ctx: AnalysisContext) -> list[Provider]:
    loader_info = ctx.attrs.fabric_loader[FabricLoaderInfo]
    mc_info = ctx.attrs.minecraft_version[MinecraftInfo]

    mods = [ctx.attrs.mod] + ctx.attrs.extra_mods
    mod_jars = {}
    for mod in mods:
        jar = mod[JavaLibraryInfo].jar
        if jar:
            mod_jars[jar.basename] = jar

    common_libs_dir = ctx.actions.declare_output(ctx.attrs.name + "-common-libs", dir = True)
    ctx.actions.symlinked_dir(
        common_libs_dir.as_output(),
        {jar.basename: jar for jar in loader_info.common_libraries},
    )

    mods_dir = ctx.actions.declare_output(ctx.attrs.name + "-mods", dir = True)
    ctx.actions.symlinked_dir(mods_dir.as_output(), mod_jars)

    main_class = "net.fabricmc.loader.impl.launch.knot.KnotServer" if ctx.attrs.side == "server" else "net.fabricmc.loader.impl.launch.knot.KnotClient"

    if ctx.attrs.side == "client":
        if not ctx.attrs.assets:
            fail("fabric_dev_launcher(side = \"client\") requires `assets` (a minecraft_assets() target)")
        assets_arg = ctx.attrs.assets
        launch_info_arg = mc_info.launch_info
    else:
        assets_arg = "-"
        launch_info_arg = "-"

    # Defaults to a per-target dir under a top-level run/ folder (like a
    # typical Fabric/Loom dev workspace's run/client, run/server), not
    # anywhere under buck-out - world saves/logs/options should survive a
    # `buck2 clean`, and client/server (or multiple mods) must not default to
    # the same dir and clobber each other's state.
    run_dir = ctx.attrs.run_dir or ("run/" + ctx.attrs.name)

    run_info = RunInfo(args = cmd_args([
        "bash",
        ctx.attrs._launcher_script,
        loader_info.loader_jar,
        common_libs_dir,
        mc_info.libraries_dir,
        ctx.attrs.merged_jar,
        mods_dir,
        main_class,
        run_dir,
        ctx.attrs.side,
        assets_arg,
        launch_info_arg,
    ]))

    return [DefaultInfo(), run_info]

fabric_dev_launcher = rule(
    doc = """A runnable dev launcher for a fabric_mod(), no installer/`mods/` folder
    needed: assembles fabric-loader + its runtime deps + the target Minecraft
    version's own libraries + the merged game jar + the mod jar(s) into a
    classpath, and directly invokes Fabric Loader's Knot{Client,Server} entrypoint.

    Run it with e.g. `buck2 run //examplemod:run_server`. Extra args after a
    literal `--` are forwarded to the JVM/game, e.g.
    `buck2 run //examplemod:run_server -- --nogui`.
    """,
    impl = _fabric_dev_launcher_impl,
    attrs = {
        "assets": attrs.option(attrs.source(), default = None, doc = "Output of a minecraft_assets() - required when side = \"client\""),
        "extra_mods": attrs.list(attrs.dep(providers = [JavaLibraryInfo]), default = []),
        "fabric_loader": attrs.dep(providers = [FabricLoaderInfo]),
        "merged_jar": attrs.source(doc = "Output of a minecraft_merged_jar()"),
        "minecraft_version": attrs.dep(providers = [MinecraftInfo]),
        "mod": attrs.dep(providers = [JavaLibraryInfo]),
        "run_dir": attrs.option(attrs.string(), default = None, doc = "Working directory the game is launched from (world save, logs, run-time config land here) - persists across runs/rebuilds. Defaults to run/<target name> (e.g. run/run_server), *not* anywhere under buck-out, so `buck2 clean` doesn't wipe it and different targets don't collide. Relative paths are resolved from wherever `buck2 run` itself is invoked."),
        "side": attrs.enum(["client", "server"], default = "server", doc = "client needs LWJGL natives and a display and isn't wired up here yet - server is the practical option for headless dev/test."),
        "_launcher_script": attrs.source(default = "//tools:fabric_dev_launcher.sh"),
    },
)

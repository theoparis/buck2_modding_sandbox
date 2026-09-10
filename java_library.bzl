# A minimal, from-scratch replacement for prelude's `java_library`/`java_binary`.
#
# See toolchains/java.bzl for why we're not using prelude's Java rules: they
# pull in prelude//toolchains/android/... sources which don't build against a
# bleeding-edge JDK. This is a small reimplementation covering just what we
# need: compile a handful of `.java` files (+ optional resources) against a
# classpath assembled from deps and raw prebuilt jars, and package the result
# as a jar.

load("@toolchains//:java.bzl", "JavaToolchainInfo")

JavaLibraryInfo = provider(fields = [
    "jar",  # artifact | None - this library's own output jar (None if header-only/no srcs+resources)
    "classpath",  # list[artifact] - this library's jar plus all transitive deps' jars, deduped
])

def _classpath_of(dep) -> list[Artifact]:
    info = dep[JavaLibraryInfo]
    return info.classpath

def _java_library_impl(ctx: AnalysisContext) -> list[Provider]:
    toolchain = ctx.attrs._java_toolchain[JavaToolchainInfo]

    transitive_classpath = []
    for dep in ctx.attrs.deps:
        transitive_classpath += _classpath_of(dep)
    transitive_classpath += ctx.attrs.prebuilt_jars

    # Dedupe while preserving order.
    seen = {}
    classpath = []
    for jar in transitive_classpath:
        if jar not in seen:
            seen[jar] = True
            classpath.append(jar)

    output_jar = None
    if ctx.attrs.srcs or ctx.attrs.resources or ctx.attrs.resource_map:
        jar_content_dirs = []

        if ctx.attrs.srcs:
            classes_dir = ctx.actions.declare_output(ctx.attrs.name + "-classes", dir = True)
            compile_cmd = cmd_args(toolchain.javac)
            compile_cmd.add("-d", classes_dir.as_output())
            compile_cmd.add("--release", ctx.attrs.java_version)
            compile_cmd.add("-encoding", "UTF-8")
            if classpath:
                compile_cmd.add("-cp", cmd_args(classpath, delimiter = ":"))
            compile_cmd.add(ctx.attrs.srcs)
            ctx.actions.run(compile_cmd, category = "javac")
            jar_content_dirs.append(classes_dir)

        # Resources are symlinked into their own directory, keyed by their
        # path relative to the repo root (short_path), then merged into the
        # jar alongside the compiled classes via repeated `-C` args.
        if ctx.attrs.resources or ctx.attrs.resource_map:
            resources_dir = ctx.actions.declare_output(ctx.attrs.name + "-resources", dir = True)
            resource_map = {}
            for res in ctx.attrs.resources:
                resource_map[res.short_path] = res
            for dest, res in ctx.attrs.resource_map.items():
                resource_map[dest] = res
            ctx.actions.symlinked_dir(resources_dir.as_output(), resource_map)
            jar_content_dirs.append(resources_dir)

        output_jar = ctx.actions.declare_output(ctx.attrs.name + ".jar")
        jar_cmd = cmd_args(toolchain.jar)
        jar_cmd.add("--create", "--file", output_jar.as_output())
        if ctx.attrs.main_class:
            jar_cmd.add("--main-class", ctx.attrs.main_class)
        for content_dir in jar_content_dirs:
            jar_cmd.add("-C", content_dir, ".")
        ctx.actions.run(jar_cmd, category = "jar")

    full_classpath = ([output_jar] if output_jar else []) + classpath

    providers = [
        JavaLibraryInfo(
            jar = output_jar,
            classpath = full_classpath,
        ),
    ]
    if output_jar:
        providers.append(DefaultInfo(default_output = output_jar))
    else:
        providers.append(DefaultInfo())
    return providers

java_library = rule(
    doc = "A minimal java_library: compiles `srcs` (+ merges in `resources`) into a single jar, using a classpath built from `deps` and `prebuilt_jars`.",
    impl = _java_library_impl,
    attrs = {
        "deps": attrs.list(attrs.dep(providers = [JavaLibraryInfo]), default = []),
        "java_version": attrs.string(default = "21", doc = "Passed to javac's --release"),
        "main_class": attrs.option(attrs.string(), default = None),
        "prebuilt_jars": attrs.list(attrs.source(), default = [], doc = "Raw jars (e.g. downloaded artifacts) to add to the classpath/output without going through another java_library()"),
        "resource_map": attrs.dict(attrs.string(), attrs.source(), default = {}, doc = "Resources placed at an explicit jar-relative path (e.g. {'fabric.mod.json': ':fmj'}), for files whose short_path doesn't match where they need to land in the jar."),
        "resources": attrs.list(attrs.source(), default = []),
        "srcs": attrs.list(attrs.source(), default = []),
        "_java_toolchain": attrs.toolchain_dep(default = "toolchains//:java", providers = [JavaToolchainInfo]),
    },
)

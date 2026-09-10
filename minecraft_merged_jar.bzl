load("//minecraft_info.bzl", "MinecraftInfo")

def _minecraft_merged_jar_impl(ctx: AnalysisContext) -> list[Provider]:
    info = ctx.attrs.minecraft_version[MinecraftInfo]

    output = ctx.actions.declare_output(ctx.attrs.name + ".jar")
    cmd = cmd_args([
        "python3",
        ctx.attrs._merge_script,
        "--client",
        info.client_jar,
        "--server",
        info.server_jar,
        "--output",
        output.as_output(),
    ])
    ctx.actions.run(cmd, category = "merge_jars")

    return [DefaultInfo(default_output = output)]

minecraft_merged_jar = rule(
    doc = "Merges a minecraft_version()'s client and server jars into one jar (see tools/merge_jars.py for caveats vs. Fabric Loom's real JarMerger).",
    impl = _minecraft_merged_jar_impl,
    attrs = {
        "minecraft_version": attrs.dep(providers = [MinecraftInfo]),
        "_merge_script": attrs.source(default = "//tools:merge_jars.py"),
    },
)

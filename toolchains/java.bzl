# A minimal, from-scratch Java toolchain.
#
# We deliberately do NOT use `prelude//toolchains:java.bzl` (`javacd_toolchain` /
# `system_java_bootstrap_toolchain`). Those toolchains wire in `jar_builder` and
# `zip_scrubber` tools that live under `prelude//toolchains/android/...`. That
# directory is Buck2's own vendored copy of (parts of) Buck1's Java/Android
# support, and building it from source pulls in a large tree of legacy Java
# code that assumes an old, specific JDK. On a bleeding-edge JDK (see `java
# -version`) those sources fail to compile/run (removed/altered internal APIs,
# stricter module boundaries, etc.), which breaks the build before we ever get
# to compiling *our* mod code.
#
# Instead, this toolchain just exposes `java`, `javac`, and `jar` from $PATH
# and `java_library.bzl` drives them directly with plain command lines. This
# sidesteps the android/javacd machinery entirely - at the cost of the fancier
# features (ABI generation, dep-file tracking, etc.) that we don't need here.

JavaToolchainInfo = provider(fields = [
    "java",  # RunInfo
    "javac",  # RunInfo
    "jar",  # RunInfo
])

def _system_java_toolchain_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        JavaToolchainInfo(
            java = RunInfo(args = [ctx.attrs.java]),
            javac = RunInfo(args = [ctx.attrs.javac]),
            jar = RunInfo(args = [ctx.attrs.jar]),
        ),
    ]

system_java_toolchain = rule(
    doc = "A from-scratch Java toolchain that just shells out to `java`/`javac`/`jar` on $PATH, bypassing prelude's javacd/android toolchain machinery.",
    impl = _system_java_toolchain_impl,
    attrs = {
        "java": attrs.string(default = "java"),
        "javac": attrs.string(default = "javac"),
        "jar": attrs.string(default = "jar"),
    },
    is_toolchain_rule = True,
)

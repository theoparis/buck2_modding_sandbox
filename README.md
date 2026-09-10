# What

This repo explores using [Buck 2](https://buck2.build), a Bazel-like build tool from Meta,
to build Minecraft mods.

The goal is to compile a working Fabric example mod, but using Buck 2, without any Gradle
or Loom.

## Why Buck 2

I wanted something with the following properties:

- Reproducible/Auditable: Recent security events have shown that supply chain compromise in
  Minecraft modding is a real and massive risk.
- Efficient: Gradle spinning = not fun.
- Deterministic/Stable: No nuking your cache randomly and praying. The goal is to be
  perfectly reliable.

Buck 2 descends from Buck 1 and further was inspired by Blaze (Bazel's closed-source
sibling). All ofthe build systems in this family value the above properties.

## Why not Bazel?

Of the hermetic Blaze-like build systems, Bazel is ths most mature and widely used, but a
couple reasons made be try Buck 2:

1. Bazel doesn't support dynamic dependencies. That is, taking an artifact as input, and
   based on that artifact's materialized contents, dynamically produce more build targets.
   This is crucial for implementing automated parsing of version.json, downloading assets
   and libraries, etc. The workaround in Bazel is to codegen the build definitions, which
   seems extremely brittle and prone to the same "nuke cache, rerun build multiple times,
   and pray til it works" that I wished to avoid with Gradle.
2. Buck 2 is written in Rust and from my experience using it internally at Meta, it's
   fast. Bazel is written in Java, like Buck 1, which can chug sometimes.
3. I work at Meta, so good old homerism :)

## Needed tools

- Java toolchain
  - Unfortunately, Buck2's Java support is very immature as it has a lot of internal-only
    minutiae. It's probably easier to reimplement the java rules we need ourselves from
    first-principles (aka reading the `javac` manual page).
  - Concretely: `prelude//toolchains:java.bzl`'s toolchains (`javacd_toolchain`,
    `system_java_bootstrap_toolchain`) default `jar_builder`/`zip_scrubber`/etc to sources
    under `prelude//toolchains/android/...`. That's Buck2's vendored copy of Buck1's
    Java/Android support, and compiling it pulls in a big tree of old Java code that
    doesn't build cleanly on a bleeding-edge JDK. We sidestep this entirely with our own
    toolchain and rules - see `toolchains/java.bzl` and `java_library.bzl`. It's much
    dumber (no ABI generation, no dep-file tracking) but it's just `javac`/`jar` from
    `$PATH`, so it builds on whatever JDK you have.
- jar merging: JarMerger (part of Fabric Loom)
  - Reimplemented minimally in `tools/merge_jars.py` (see caveats above).
- remapping: TinyRemapper (standalone binary releases on Fabric Maven)
  - Not currently used - see jar merge note above.
- mappings: Yarn/Intermediary (standalone releases on Fabric Maven)
  - Not currently used - see jar merge note above.
- Mixin
- IDE project generation: ?
  - See what Brachyura does, probably

## Fabric support

`fabric.bzl` provides:

- `fabric_loader(name, version, sha1)`: downloads a Fabric Loader release jar from the
  Fabric maven (used as a compile-time dep for `net.fabricmc.api.*` entrypoints).
- `fabric_mod(name, srcs, resources, fabric_mod_json, deps, compile_only_deps, ...)`: a
  thin macro over `java_library()` (see `java_library.bzl`) that compiles mod sources,
  drops `fabric.mod.json` at the jar root, and keeps game/loader jars (`compile_only_deps`)
  off the runtime classpath / out of the output jar, since Fabric Loader supplies those at
  runtime.

`minecraft_merged_jar.bzl` provides `minecraft_merged_jar(name, minecraft_version)`, which
merges a `minecraft_version()`'s client + server jars (see caveats above).

See `examplemod/` for a complete, working (if minimal) example mod built entirely with
Buck 2 - no Gradle, no Loom, no mappings/remapping needed since this Minecraft version
isn't obfuscated. Build it with:

```
buck2 build //examplemod:examplemod
```

## Implementation Notes

Buck 2's documentation can be kind of opaque, so here's some random notes.

Targets are the thing that you can request to be built.

Every target is a rule that has been instantiated with attributes (arguments).

Rules are functions that take the attributes and return providers.

Providers are structs representing the result of the build, for use as inputs to other
rules.

`artifact` values are not actually a compiled thing, they are tokens representing
something that will eventually be compiled or created.

## Scoping and todo

This is an experimental project, so we're going to take some shortcuts:

- Assume Minecraft 1.21.4 or later (no support for manifest/assets/library quirks from
  earlier versions)
- No multiloader or mojmap/parchment support
- Ok to vendor or manually write out dependencies instead of parsing maven POM's

- [x] version manifest and version json parsing
- [x] asset downloading
  - ish, buck2 seems to open tons of fd's which can make the download flaky
- [x] Library downloading
- [x] Client/server jar merge
  - simplified: no obfuscation to deal with for 26.3-pre-3, so this is a plain union of
    the two jars' entries (client wins on conflict), no ASM/environment-annotation
    stamping like real Fabric Loom does. See `tools/merge_jars.py`.
- [x] Build mod against merged jar (no mixins)
  - `fabric_mod()` in `fabric.bzl`, see `examplemod/` for a working example
- [ ] Remap to intermediary / Remap to named
  - Not needed for 26.3-pre-3: it's unobfuscated by default, so we skip Yarn/Intermediary
    and TinyRemapper entirely for now. Would be required to support older/obfuscated
    versions.
- [ ] Support mixins
- [ ] Process resources (insert mixin refmap name)
- [ ] Assemble final jar
- [ ] Make sure final jar seems to run

Main goal accomplished by here! Stretch goals:

- [ ] Demonstrate consuming intermediary-mapped deps
- [ ] IDE project generation
- [ ] Access Widener support
- [ ] Mojmap support
- [ ] Make the interface nicer to use as an "end user"

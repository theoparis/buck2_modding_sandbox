MinecraftInfo = provider(
    fields = [
        "version_json",  # artifact
        "client_jar",  # artifact
        "client_mappings",  # artifact
        "server_jar",  # artifact
        "server_mappings",  # artifact
        "asset_index",  # artifact
        "libraries_dir",  # artifact
        "launch_info",  # artifact (json: {"id":..., "asset_index_id":...} - see minecraft_version.bzl)
    ]
)

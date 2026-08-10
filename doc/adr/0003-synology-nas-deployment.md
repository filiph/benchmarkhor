# Synology NAS Deployment Strategy

We decided to deploy the `adb_server` to Synology NAS using Network ADB and GHCR. This avoids the complexities of USB passthrough on DSM while allowing a seamless "make push" workflow from the local development machine. Data is persisted via bind mounts to NAS shared folders for easy access via SMB.

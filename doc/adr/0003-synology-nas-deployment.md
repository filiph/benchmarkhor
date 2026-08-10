# Synology NAS Deployment Strategy

We decided to deploy the `adb_server` to Synology NAS using Network ADB and GHCR. This avoids the complexities of USB passthrough on DSM while allowing a seamless "make push" workflow from the local development machine. Data is persisted via bind mounts to NAS shared folders for easy access via SMB.

**Note on Image Distribution:**
Images are hosted on GitHub Container Registry (GHCR). However, since Synology's Container Manager GUI has known issues authenticating with GHCR, we also support a **manual export/upload** workflow. This allows users to build the image locally, export it to a `.tar` file, and upload it directly through the DSM web interface, bypassing the registry entirely for private deployments where SSH access is undesirable.

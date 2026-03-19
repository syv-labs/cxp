## cxp release repo

This folder is structured as if it were a **public GitHub repository** used only for:

- Publishing pre-built `cxp` binaries as GitHub Release assets
- Providing a simple `install.sh` for users to install `cxp` via `curl | sh`

Your actual Rust source code stays in a **separate private repo**.

### Repository layout (public release repo)

- `install.sh` – installer script users run locally
- GitHub Releases – contain the compiled `cxp` binaries and `checksums.txt`

No Rust source code is required here.

### How users will install

Assuming you push this folder as a repo named `syv-labs/cxp`, users can install with:

```bash
curl -fsSL https://raw.githubusercontent.com/syv-labs/cxp/main/install.sh | sh
```

or clone and run:

```bash
git clone https://github.com/syv-labs/cxp.git
cd cxp
sh install.sh
```

The script will:

- Detect OS and architecture
- Download the correct `cxp-<version>-<target>.tar.gz` from the repo's Releases
- Verify the checksum (if `checksums.txt` is present)
- Install the `cxp` binary to `~/.local/bin` by default

### Expected release assets

For a version `v0.1.0`, the public repo’s GitHub Release should contain assets like:

- `cxp-v0.1.0-x86_64-apple-darwin.tar.gz`
- `cxp-v0.1.0-aarch64-apple-darwin.tar.gz`
- `cxp-v0.1.0-x86_64-unknown-linux-musl.tar.gz`
- `cxp-v0.1.0-aarch64-unknown-linux-musl.tar.gz`
- `checksums.txt`

Each `.tar.gz` must contain a single executable named `cxp` (no subdirectories).

### How you produce those binaries (from your private repo)

From your **private** `cxp` repo:

1. Build release binaries (example for macOS on Apple Silicon and Linux x86_64):

```bash
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-unknown-linux-musl
```

2. Package them into tarballs named as expected:

```bash
mkdir -p dist

version="0.1.0"

cp target/aarch64-apple-darwin/release/cxp dist/cxp
tar -C dist -czf "cxp-v${version}-aarch64-apple-darwin.tar.gz" cxp

cp target/x86_64-unknown-linux-musl/release/cxp dist/cxp
tar -C dist -czf "cxp-v${version}-x86_64-unknown-linux-musl.tar.gz" cxp
```

3. Generate `checksums.txt`:

```bash
sha256sum cxp-v${version}-*.tar.gz > checksums.txt
```

4. In the **public** `cxp` repo on GitHub:

- Create a new Release with tag `v0.1.0`
- Upload the `cxp-v${version}-*.tar.gz` files and `checksums.txt` as release assets

After that, the installer in this repo will work for anyone without needing access to your private code.


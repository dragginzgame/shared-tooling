# toko-tooling

A dependency-free, `no_std` version marker for the Dragginzgame shared
development tooling. This crate has no runtime API or build script.

The crates.io archive contains the marker library, this README and the MIT
license. Adding it as a dependency does not install scripts or executables.

To track an installable tooling snapshot, declare the Git dependency in a private
tooling package:

```toml
[dev-dependencies]
toko-tooling = { git = "https://github.com/dragginzgame/shared-tooling", branch = "main" }
```

After updating Cargo.lock, run `make shared-tooling-install` in a consumer that
has adopted the shared tooling. The installer requires the exact Git revision;
registry dependencies cannot select installable snapshots.

See the [snapshot adoption guide](https://github.com/dragginzgame/shared-tooling/blob/main/docs/consuming-snapshots.md)
for initial setup and update commands.

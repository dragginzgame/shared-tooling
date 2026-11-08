//! Shared development tooling distributed as a crates.io source bundle.
//!
//! Select it through repository-root Cargo metadata and `toko-tooling.lock`,
//! independently of application dependencies. Run `make shared-tooling-update`
//! after changing the declared version to install its authenticated source payload.
//! Installation never runs implicitly during a Cargo build.
#![no_std]

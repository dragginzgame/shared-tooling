//! Shared development tooling distributed as a crates.io source bundle.
//!
//! Select it with one exact root Cargo pin inherited as a dev-dependency by
//! every workspace package. Cargo.lock supplies the source archive checksum.
//! Run `make shared-tooling-update` after updating the pin and Cargo.lock
//! to install the authenticated source payload.
//! Installation never runs implicitly during a Cargo build.
#![no_std]

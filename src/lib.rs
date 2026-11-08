//! Shared development tooling distributed as a Cargo source bundle.
//!
//! The crate contains the scripts, Make interfaces, CI actions and engineering
//! documentation. After updating this dev-dependency, run
//! `make shared-tooling-install` to install the locked registry payload and admit
//! its pinned tools. Installation never runs implicitly during a Cargo build.
#![no_std]

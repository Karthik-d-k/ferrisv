// SPDX-License-Identifier: GPL-2.0

//! ferrisv: a minimal out-of-tree Rust kernel module for RISC-V.
//!
//! Build: `just qemu`. In the guest: mount the 9p share, then `insmod .../rust_hello.ko`.

use kernel::prelude::*;

module! {
    type: RustHello,
    name: "rust_hello",
    authors: ["ferrisv"],
    description: "Minimal out-of-tree Rust module (ferrisv)",
    license: "GPL",
}

struct RustHello;

impl kernel::Module for RustHello {
    fn init(_module: &'static ThisModule) -> Result<Self> {
        let task = current!();

        pr_info!("ferrisv: rust_hello loaded on RISC-V\n");
        pr_info!("ferrisv: built-in? {}\n", !cfg!(MODULE));
        pr_info!("Current process PID: {}\n", task.pid());

        Ok(RustHello)
    }
}

impl Drop for RustHello {
    fn drop(&mut self) {
        pr_info!("ferrisv: rust_hello unloaded\n");
    }
}

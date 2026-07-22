# ferrisv 🦀

Out-of-tree **Rust kernel modules for RISC-V**, cross-built with LLVM and run under
QEMU via [virtme-ng](https://github.com/arighi/virtme-ng). A playground for learning
Linux driver development in Rust: **linux + rust + riscv + qemu**.

## Layout

Each module is a self-contained subdirectory (`obj-m := <name>.o` in its `Kbuild`):

```
ferrisv/
├── justfile              # dev loop: build -> load in guest -> dmesg
├── rust_hello/           # a minimal module (start here)
│   ├── Kbuild            #   obj-m := rust_hello.o
│   └── rust_hello.rs
└── rust_chardev/         # (future) a character device, then real drivers...
```

Expected sibling directories, one level up:

```
~/os/
├── linux/                              # rust-enabled kernel tree (CONFIG_RUST=y), built once
├── jammy-server-cloudimg-riscv64-root/ # vng rootfs (auto-created on first run)
└── ferrisv/                            # this repo
```

## Prerequisites

- `../linux` built with `CONFIG_RUST=y` (`Image` + `modules`) using LLVM.
- LLVM (e.g. 22) on `PATH`, so `LLVM=1` selects clang/lld and its major version
  must match `rustc`'s LLVM.
- `rustc` + `bindgen` (rustup), `just`, `virtme-ng` (`vng`), `qemu-system-riscv64`.

## Usage

```bash
just mod=rust_hello test     # build, load in the guest, print dmesg, unload
just mod=rust_hello shell    # interactive guest shell (module staged at /tmp/rust_hello.ko)
```

## How it works

`just build` runs `make -C ../linux M=$PWD/<mod> ARCH=riscv LLVM=1`, it borrows the
kernel's kbuild to cross-compile the module against the rust-enabled tree. The resulting
`.ko` is copied into the rootfs and `insmod`ed inside the QEMU guest. (Host paths aren't
shared cross-arch, so the module is staged into the rootfs first, appearing at `/tmp/`.)

## License

GPL-2.0 is required, since the Rust kernel APIs are `EXPORT_SYMBOL_GPL`.

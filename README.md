# ferrisv 🦀

Out-of-tree **Linux kernel modules in C/Rust for RISC-V**, cross-built with **LLVM** and run under **QEMU**.

`just qemu` boots OpenSBI -> kernel -> init on an ext4 root and 9p-shares the whole repo into the
guest, so you `insmod`/`rmmod` and iterate without rebuilding the world.

## Layout

Clone the pieces as **siblings**; ferrisv finds them via `../`:

```
<workspace>/
├── linux/       # Rust-enabled kernel   (just kernel)
├── buildroot/   # rootfs + OpenSBI      (just buildroot)
└── ferrisv/     # this repo
```

Each module is a self-contained dir with its own `Kbuild` (`obj-m := <name>.o`):

```
ferrisv/
├── justfile                  # dev loop: buildroot / kernel / qemu
├── configs/                  # Buildroot defconfig
├── rust_hello/               # minimal Rust module : start here
├── c_hello/                  # minimal C module
└── <new_module>/             # copy rust_hello/c_hello/ and set `obj-m` in its Kbuild
```

## Setup

Pinned versions, so the stack is reproducible:

| tool | version | role |
|---|---|---|
| linux | v7.1 | kernel tree (shallow clone) |
| buildroot | 2026.05.1 | rootfs + OpenSBI firmware |
| Bootlin toolchain | riscv64-lp64d glibc 2025.08-1 | RISC-V cross-compiler |
| LLVM | 22.1.8 | builds the kernel (required for Rust) |

Install `just` and `qemu-system-riscv64` from your package manager. Rust/bindgen setup follows the
[Rust-for-Linux quick-start](https://docs.kernel.org/rust/quick-start.html) (verify with
`make LLVM=… rustavailable`); Buildroot host deps follow the
[Buildroot manual](https://buildroot.org/downloads/manual/manual.html).

Clone the siblings and unpack the toolchains:

```bash
# kernel (shallow clone -> fetch the tag, then check it out)
git clone --depth 1 https://github.com/torvalds/linux.git && cd linux && git fetch --depth 1 origin tag v7.1 && git checkout v7.1 && cd ..

# buildroot (full clone -> direct checkout)
git clone https://github.com/buildroot/buildroot.git && cd buildroot && git checkout 2026.05.1 && cd ..

# RISC-V cross-toolchain -> ~/tools
cd ~/tools && wget https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2025.08-1.tar.xz && tar -xf riscv64-lp64d--glibc--stable-2025.08-1.tar.xz

# LLVM -> ~/tools
cd ~/tools && wget https://mirrors.edge.kernel.org/pub/tools/llvm/files/llvm-22.1.8-x86_64.tar.xz && tar -xf llvm-22.1.8-x86_64.tar.xz
```

`just` reads the LLVM path from `llvmdir` (default `~/tools/llvm-22.1.8-x86_64`); the defconfig finds
the cross-toolchain via `BR2_TOOLCHAIN_EXTERNAL_PATH`. Bump a pin later with
`gh api repos/:owner/:repo/tags`.

## Usage

```bash
just qemu                              # build rust_hello module + boot the full stack (auto-builds kernel/rootfs if missing)
just module=rust_hello qemu            # pick a module dir to build/boot
just module=c_hello qemu               # e.g. the C module
```

In the guest, mount the 9p share (repo root) and load a module:

```sh
mkdir -p /mnt/mods
mount -t 9p -o trans=virtio,version=9p2000.L mods /mnt/mods
insmod /mnt/mods/rust_hello/rust_hello.ko ; dmesg | tail    # load  (init) message
rmmod rust_hello ; dmesg | tail                             # unload (Drop) message
```

**Fast loop:** keep the guest running and rebuild only the selected module's `.ko` on the host:
`make -C ../linux M=$PWD/<mod> ARCH=riscv LLVM=<llvm-bin>/`. The 9p share is live, so
`rmmod … ; insmod …` in the guest picks it up in seconds, no reboot. (`snapshot=on` discards guest
writes; exit QEMU with `Ctrl-a x`.)

## Editor setup

Shared `.vscode/settings.json` wires clangd (C) and rust-analyzer (Rust). Generated index files per
module are gitignored:

```bash
just module=c_hello c-analyzer       # -> c_hello/compile_commands.json  (clangd, C)
just module=rust_hello rust-analyzer # -> rust_hello/rust-project.json   (rust-analyzer, Rust)
```

## Rebuilds

Deps auto-build on the first `just qemu`. Force a rebuild after a config change:

```bash
just buildroot   # ../buildroot -> rootfs.ext4, fw_dynamic.bin
just kernel      # ../linux -> Image + modules  (modules -> Module.symvers, needed by OOT builds)
```

Edit the Buildroot config with `make -C ../buildroot menuconfig`, then `just save-buildroot-config`.
The kernel config is pure upstream: `make defconfig` + `make rust.config`.

## How it works

C and Rust modules borrow the kernel's kbuild (`make -C ../linux M=$PWD/<mod> ARCH=riscv LLVM=…`),
cross-compiling against the LLVM/Rust-enabled tree. The `.ko` files reach the guest over a 9p share
and are `insmod`ed. QEMU supplies the board; `../linux` the `Image`; `../buildroot` the ext4 rootfs
and OpenSBI (`fw_dynamic.bin`).

## License

GPL-2.0 : the Rust kernel APIs are `EXPORT_SYMBOL_GPL`.

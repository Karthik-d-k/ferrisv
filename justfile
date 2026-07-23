# ferrisv: out-of-tree Rust kernel modules for RISC-V, run under QEMU/virtme-ng
#
# Each module is a subdir (rust_hello/, rust_chardev/, ...) with its own
# Kbuild (obj-m := <name>.o) + <name>.rs. Select one with `module=`:
#   just module=rust_hello test     # build -> load in guest -> dmesg -> unload
#   just new rust_chardev        # scaffold the next experiment
#
# Siblings one level up (../): the rust-enabled kernel tree and the vng rootfs.
# Build the kernel once in ../linux (CONFIG_RUST=y) before using this repo.

kdir    := "../linux"
rootfs  := "../jammy-server-cloudimg-riscv64-root"
release := "jammy"
image   := kdir / "arch/riscv/boot/Image"
llvmdir := env('HOME') + "/tools/llvm-22.1.8-x86_64"
llvm    := llvmdir + "/bin/"
export LIBCLANG_PATH := llvmdir + "/lib"
module     := "rust_hello"          # which module dir to act on; override: just module=NAME test

# print the recipe list when you run a bare `just`
default:
    @just --list

# build the selected module against the kernel tree (kbuild reads {{module}}/Kbuild)
build:
    make -C {{kdir}} M=$(pwd)/{{module}} ARCH=riscv LLVM={{llvm}}

# create the rootfs if missing, same curl|tar as vng's create_root
_ensure-rootfs:
    sudo mkdir -p {{rootfs}}
    test -e {{rootfs}}/etc/os-release \
      || curl -sL "https://cloud-images.ubuntu.com/{{release}}/current/{{release}}-server-cloudimg-riscv64-root.tar.xz" \
        | sudo tar xvJ -C {{rootfs}}

# copy the built .ko into the guest rootfs (-> /tmp/ in the guest)
copy: build _ensure-rootfs
    cp {{module}}/{{module}}.ko {{rootfs}}/tmp/

# load -> dmesg -> unload -> dmesg (the inner dev loop)
test: copy
    vng -r {{image}} --arch riscv64 --root {{rootfs}} --user root -- \
      bash -c 'dmesg -C; insmod /tmp/{{module}}.ko; dmesg; dmesg -C; rmmod {{module}}; dmesg'

# interactive root shell in the guest (module already staged at /tmp/{{module}}.ko)
shell: copy
    vng -r {{image}} --arch riscv64 --root {{rootfs}} --user root

# remove build artifacts for the selected module
clean:
    make -C {{kdir}} M=$(pwd)/{{module}} clean

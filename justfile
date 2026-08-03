# ferrisv: out-of-tree Rust kernel modules for RISC-V, run under QEMU.
#
# One command boots the full system and shares the module dir into the guest over 9p:
#   just qemu      -> OpenSBI -> kernel -> init on ext4; module dir at 9p tag "mods"
# Dependencies auto-build on first `just qemu`; run these explicitly to force a rebuild:
#   just buildroot -> rootfs + OpenSBI firmware (../buildroot)
#   just kernel    -> Rust-enabled kernel (../linux)
#
# Pick a module with `module=`:   just module=rust_hello qemu

kdir      := "../linux"
brdir     := "../buildroot"
images    := brdir / "output/images"
image     := kdir / "arch/riscv/boot/Image"
symvers   := kdir / "Module.symvers"
bios      := images / "fw_dynamic.bin"
ext4      := images / "rootfs.ext4"
brdefconfig := justfile_directory() / "configs/qemu_riscv64_virt_dk_defconfig"

llvmdir   := env('HOME') + "/tools/llvm-22.1.8-x86_64"
llvm      := llvmdir + "/bin/"
export LIBCLANG_PATH := llvmdir + "/lib"

# WSL: Buildroot refuses a PATH containing spaces/tabs (the Windows /mnt/c entries). Strip any
# whitespace-containing entries for every recipe, so `just buildroot` works without you having to
# fix your interactive shell first. No-op on a clean Linux PATH.
export PATH := `echo "$PATH" | tr ':' '\n' | grep -v '[[:space:]]' | paste -sd ':'`

module    := "rust_hello"          # which module dir to act on

# show the runnable recipes on a bare `just`
default:
    @just --list

# === run ===================================================================

# full-system boot: OpenSBI -> kernel -> init on ext4; module dir 9p-shared at tag "mods"
qemu: _build _buildroot
    # live loop: rebuild the .ko on the host; the running guest sees it via 9p (rmmod/insmod, no reboot)
    @echo '>> in guest: mkdir -p /mnt/mods && mount -t 9p -o trans=virtio,version=9p2000.L mods /mnt/mods && insmod /mnt/mods/{{module}}.ko'
    qemu-system-riscv64 -M virt -m 1G -smp 2 -nographic \
      -bios {{bios}} -kernel {{image}} \
      -append "root=/dev/vda rw console=ttyS0" \
      -drive file={{ext4}},format=raw,snapshot=on,id=hd0,if=none \
      -device virtio-blk-device,drive=hd0 \
      -fsdev local,id=fs0,path=$(pwd)/{{module}},security_model=none \
      -device virtio-9p-device,fsdev=fs0,mount_tag=mods

# === (re)build a whole dependency: run explicitly to force it ==============

# build the Buildroot rootfs + OpenSBI firmware from ferrisv's defconfig (../buildroot)
buildroot:
    make -C {{brdir}} defconfig BR2_DEFCONFIG={{brdefconfig}}
    make -C {{brdir}} -j`nproc`

# build the Rust-enabled kernel: riscv defconfig + rust.config -> Image + modules
kernel:
    # `modules` is required: it generates Module.symvers, which out-of-tree builds link against
    make -C {{kdir}} ARCH=riscv LLVM={{llvm}} defconfig
    make -C {{kdir}} ARCH=riscv LLVM={{llvm}} rust.config
    make -C {{kdir}} ARCH=riscv LLVM={{llvm}} -j`nproc` Image modules

# write Buildroot menuconfig edits back into ferrisv/configs (after `make -C ../buildroot menuconfig`)
save-buildroot-config:
    make -C {{brdir}} savedefconfig BR2_DEFCONFIG={{brdefconfig}}

# generate rust-project.json for rust-analyzer (module = the selected one)
rust-analyzer:
    make -C {{kdir}} ARCH=riscv LLVM={{llvm}} M=$(pwd)/{{module}} rust-analyzer

# Generate Rust documentation
rustdoc:
    make -C {{kdir}} ARCH=riscv LLVM={{llvm}} rustdoc
    @echo ">> open: {{kdir}}/Documentation/output/rust/rustdoc/kernel/index.html"

# remove the selected module's build artifacts
clean:
    make -C {{kdir}} M=$(pwd)/{{module}} clean

# === internal: lazy guards (build a dependency only if its artifact is absent) ===

# ensure the kernel Image AND Module.symvers exist (both come from `just kernel`)
_kernel:
    test -e {{image}} && test -e {{symvers}} || just kernel

# ensure the Buildroot images (rootfs + firmware) exist
_buildroot:
    test -e {{ext4}} || just buildroot

# compile the selected module (needs the prepared kernel tree, hence _kernel)
_build: _kernel
    make -C {{kdir}} M=$(pwd)/{{module}} ARCH=riscv LLVM={{llvm}}

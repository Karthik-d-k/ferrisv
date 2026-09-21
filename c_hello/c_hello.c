// ferrisv: a minimal out-of-tree C kernel module for RISC-V.
//
// Build: `just qemu`. In the guest: mount the 9p share,
// then `insmod .../rust_hello.ko`.

#include <linux/init.h>
#include <linux/module.h>
#include <linux/printk.h>

static int __init my_init(void) {
  pr_info("ferrisv: c_hello loaded on RISC-V\n");
  // pr_info("ferrisv: built-in? {}\n",);
  // pr_info("Current process PID: {}\n", task.pid());

  return 0;
}

static void __exit my_exit(void) {
  /* no return */
  pr_info("ferrisv: c_hello unloaded\n");
}

module_init(my_init);
module_exit(my_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("ferrisv");
MODULE_DESCRIPTION("Minimal out-of-tree C module (ferrisv)");

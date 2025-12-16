# XHCI / Verity bug reproduction

This builds an initrd and a disk image with nix, if you don't have nix,
sample images may be found in:
https://github.com/baloo/xhci-verity/releases/tag/2025.12.16

```
cp .config ../linux/.config
cd ../linux
make olddefconfig
make -j 16
```


```
$ nix-build run.nix
$ ./result/bin/xhci-run ../linux/arch/x86/boot/bzImage
[...]
[   25.792598] device-mapper: verity: 8:2: metadata block 66244 is corrupted][eta 01d:20h:24m:56s]
[   25.793176] Kernel panic - not syncing: dm-verity device corrupted
[   25.793690] CPU: 0 PID: 33 Comm: kworker/u3:0 Not tainted 6.1.0 #2
[   25.794221] Hardware name: QEMU Standard PC (i440FX + PIIX, 1996), BIOS rel-1.17.0-0-gb52ca86e094d-prebuilt.qemu.org 04/01/2014
[   25.795159] Workqueue: kverityd verity_work
[   25.795500] Call Trace:
[   25.795708]  <TASK>
[   25.795901]  dump_stack_lvl+0x41/0x5d
[   25.796214]  panic+0xfa/0x256
[   25.796460]  ? snprintf+0x3d/0x60
[   25.796733]  verity_handle_err.cold+0x2b/0x44
[   25.797106]  verity_verify_level+0x1a0/0x1d0
[   25.797451]  verity_hash_for_block+0xd9/0x110
[   25.797812]  verity_verify_io+0x16e/0x510
[   25.798161]  verity_work+0x1e/0x40
[   25.798442]  process_one_work+0x20e/0x400
[   25.798772]  worker_thread+0x51/0x3f0
[   25.799109]  ? process_one_work+0x400/0x400
[   25.799449]  kthread+0xea/0x120
[   25.799708]  ? kthread_exit+0x40/0x40
[   25.800038]  ret_from_fork+0x1f/0x30
[   25.800336]  </TASK>
```


https://www.kernel.org/doc/html/latest/process/debugging/gdb-kernel-debugging.html
```
gdb --eval-command="target remote :1234" --eval-command="b verity_handle_err" --eval-command="c" vmlinux
```

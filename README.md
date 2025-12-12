# XHCI / Verity bug reproduction


```
cp config ../linux/.config
cd ../linux
make olddefconfig
make -j 16
```


```
nix-build run.nix
./result/bin/xhci-run ../linux/arch/x86/boot/bzImage
```

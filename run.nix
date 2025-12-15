with import <nixpkgs> {};

let
  assets = import ./assets.nix;
in
writeShellApplication {
  name = "xhci-run";
  runtimeInputs = [
    qemu_kvm
  ];

  text = ''
    kernel=$1
    roothash=$(jq -r '.[0].roothash' "${assets}/repart-output.json")

    rm -rf /tmp/image
    cp ${assets}/image /tmp/image
    chmod 644 /tmp/image

    qemu-kvm \
        -no-user-config -nodefaults \
        \
        -kernel "''${kernel}" \
        -initrd "${assets}/initrd" \
        -append "console=ttyS0 panic=-1 roothash=''${roothash}" \
        \
        -display none \
        -serial stdio \
        \
        -drive if=none,id=usbstick,format=raw,file=/tmp/image \
        -device nec-usb-xhci,id=xhci \
        -device usb-storage,bus=xhci.0,drive=usbstick \
        \
        -usb -device usb-tablet,bus=usb-bus.0 \
        \
        -m 2G -cpu max -smp 1 \
        -no-reboot

    rm /tmp/image
  '';
}

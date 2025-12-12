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

    qemu-kvm \
        -no-user-config -nodefaults \
        \
        -kernel "''${kernel}" \
        -initrd "${assets}/initrd" \
        -append "console=ttyS0 roothash=''${roothash}" \
        \
        -display none \
        -serial stdio \
        \
        -drive if=none,id=usbstick,format=raw,readonly=on,file=${assets}/image \
        -device nec-usb-xhci,id=xhci \
        -device usb-storage,bus=xhci.0,drive=usbstick \
        -m 4G
  '';
}

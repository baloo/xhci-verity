with import <nixpkgs> {};

let
  assets = import ./assets.nix;
  runner = writeShellApplication {
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
          -append "console=ttyS0 panic=-1 roothash=''${roothash} nokaslr noexec=off" \
          \
          -display none \
          -serial stdio \
          \
          -drive if=none,id=usbstick,format=raw,readonly=on,file=${assets}/image \
          -device nec-usb-xhci,id=xhci \
          -device usb-storage,bus=xhci.0,drive=usbstick \
          \
          -usb -device usb-tablet,bus=usb-bus.0 \
          \
          -m 2G -cpu max -smp 1 \
          -no-reboot \
          \
          -gdb tcp::1234
    '';
  };
in runCommand "run" {} ''
  mkdir $out $out/bin
  ln -s ${runner}/bin/xhci-run $out/bin
  ln -s ${assets}/image $out/
  ln -s ${assets}/initrd $out/
  ln -s ${assets}/repart-output.json $out/
''

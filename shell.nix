with import <nixpkgs> {};

mkShell {
  buildInputs = [
    qemu_kvm
  ];
}

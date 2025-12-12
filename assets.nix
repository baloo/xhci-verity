with import <nixpkgs> {};

let
  randomDataImg = "/tmp/data";
  part-root = writeText "root-verity.conf" ''
     [Partition]
     Type=usr
     Verity=data
     VerityMatchKey=root
     CopyFiles=${randomDataImg}
     Minimize=best
     Format=erofs
  '';
  part-root-hash = writeText "root-verity-hash.conf" ''
    [Partition]
    Type=usr-verity
    Verity=hash
    VerityMatchKey=root
    Minimize=best
  '';
  repartConfig = runCommand "repart.conf.d" {} ''
    mkdir $out
    ln -s ${part-root} $out/10-root.conf
    ln -s ${part-root-hash} $out/20-root-hash.conf
  '';

  diskImage = runCommand "image" { 
    buildInputs = [
      util-linux
      fakeroot
      systemd
      erofs-utils
    ];
  } ''
    mkdir ${randomDataImg}
    dd if=/dev/random of=${randomDataImg}/target bs=4M count=308

    unshare --map-root-user fakeroot \
      systemd-repart --definitions ${repartConfig} \
      --dry-run=no \
      --json=pretty \
      --empty=create --size=auto \
      image \
      | tee repart-output.json

    mkdir -p $out
    cp image repart-output.json $out/
  '';

  fio-config = writeText "randomread.fio" ''
    [global]
    bs=4K
    iodepth=64
    direct=1
    ioengine=libaio
    group_reporting
    time_based
    runtime=120
    numjobs=4
    name=raw-randread
    rw=randread
    							
    [job]
    filename=/nix/store/tmp/data/target
    size=100%
  '';

  init = writeShellScript "init" ''
    export PATH=${lib.makeBinPath [ cryptsetup util-linux gnused coreutils findutils fio ]}

    set -x

    # Takes a second for /dev/sda to pop in
    sleep 1

    mount -t proc proc /proc
    mount -t devtmpfs none /dev

    roothash=$(sed -r 's/.*roothash=([^ ]+) ?.*/\1/' /proc/cmdline)
    veritysetup --panic-on-corruption open /dev/sda1 root /dev/sda2 "''${roothash}"

    find /dev -ls

    mkdir /target
    mount /dev/mapper/root /target
    mkdir -p /nix/store/tmp
    mount -o bind /target/tmp /nix/store/tmp

    find /target  /nix/store/tmp -ls

    #dd if=/dev/mapper/root of=/dev/null bs=4M

    fio ${fio-config}
  '';

  initrd = makeInitrd {
    name = "xkci-initrd";

    contents = [
      {
        object = init;
        symlink = "/init";
      }
    ];

  };
in
runCommand "assets" { } ''
  mkdir $out
  ln -s ${diskImage}/image $out/
  ln -s ${diskImage}/repart-output.json $out/
  ln -s ${initrd}/initrd $out/initrd
''

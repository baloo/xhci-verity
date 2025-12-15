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
    VerityDataBlockSizeBytes=512
    VerityHashBlockSizeBytes=512
  '';
  repartConfig = runCommand "repart.conf.d" {} ''
    mkdir $out
    ln -s ${part-root-hash} $out/10-root-hash.conf
    ln -s ${part-root} $out/20-root.conf
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
    loops=3
    #iodepth=64
    ioengine=io_uring
    group_reporting
    #time_based
    #runtime=20
    numjobs=4
    name=raw-randread
    rw=randread

    [job_fs_direct]
    bsrange=64-16k
    direct=0
    blocksize_unaligned
    filename=/target/tmp/data/target
    size=2M
    ioengine=sync
    prio=0

    [job_fs_direct_seq]
    bsrange=64-16k
    direct=0
    blocksize_unaligned
    filename=/usr/tmp/data/target
    size=100%
    ioengine=sync
    readwrite=read
    prio=7

    [job_fs_remount]
    bsrange=64-16k
    direct=0
    blocksize_unaligned
    filename=/nix/store/tmp/data/target
    size=100%

    [job_direct]
    bs=4K
    direct=1
    filename=/dev/mapper/root
    size=100%

    [job_direct_512]
    bs=512
    direct=1
    filename=/dev/mapper/root
    size=100%

    [job_direct_seq]
    bs=4K
    direct=1
    filename=/dev/mapper/root
    size=100%
    rw=read


    [job_direct_merkle]
    bs=4K
    direct=1
    filename=/dev/sda1
    size=2M

    [job_direct_data]
    bs=4K
    direct=1
    filename=/dev/sda2
    size=2M
  '';

  init = writeScript "init" ''
    #!${pkgsStatic.busybox}/bin/sh

    export PATH=${
      lib.makeBinPath (with pkgsStatic; [
        busybox
        cryptsetup
        fio
      ])
    }
    set -x

    # Takes a second for /dev/sda to pop in
    sleep 1

    mount -t proc proc /proc
    mount -t devtmpfs none /dev

    for o in $(</proc/cmdline); do
      case "$o" in
        roothash=*)
          set -- $(IFS==; echo $o)
          roothash=$2
          ;;
      esac
    done

    roothash=$(sed -r 's/.*roothash=([^ ]+) ?.*/\1/' /proc/cmdline)
    veritysetup --panic-on-corruption open /dev/sda2 root /dev/sda1 "''${roothash}"

    #find /dev -ls

    mkdir /usr
    mount -t erofs /dev/mapper/root /usr
    mkdir -p /nix/store/tmp
    mount -o bind /usr/tmp /nix/store/tmp

    mount

    #find /target  /nix/store/tmp -ls

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

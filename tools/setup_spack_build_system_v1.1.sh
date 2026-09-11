#!/bin/bash

function install_spack_build_system()
{
    Base=$1
    spackdir=$2
    opt_padding=${3:-0}

    if ! [ -d $spackdir ];then
        $(
        cd ${spackdir%/spack}
        git clone https://github.com/art-daq/spack.git -b artdaq/Spack1.1
            )
    else
        cd $spackdir && git checkout artdaq/Spack1.1 && git pull; cd $Base
    fi

    cat >setup-env.sh <<-EOF

export BUILD_J=\$((\`cat /proc/cpuinfo|grep processor|tail -1|awk '{print \$3}'\` + 1))
export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CACHE_PATH=$Base/.spack-cache
source $spackdir/share/spack/setup-env.sh
EOF

    source setup-env.sh

    if ! [ -d fermi-spack-tools ]; then
        git clone https://github.com/art-daq/fermi-spack-tools.git -b artdaq/Spack1.1
    else
        cd fermi-spack-tools && git checkout artdaq/Spack1.1 && git pull; cd $Base
    fi
    if ! [ -d spack-mpd ]; then
        git clone https://github.com/art-daq/spack-mpd.git -b artdaq/Spack1.1
    else
        cd spack-mpd && git checkout artdaq/Spack1.1 && git pull; cd $Base
    fi

    os=$(spack arch -o)
    sed -i '/perl/d' fermi-spack-tools/templates/packagelist
    touch fermi-spack-tools/templates/package_opts.$os
    if [ -f $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/$os/packages.yaml ];then
        echo "Skipping ./fermi-spack-tools/bin/make_packages_yaml $spackdir $os"
        echo "... $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/$os/packages.yaml already exists"
    else
        echo "executing ./fermi-spack-tools/bin/make_packages_yaml $spackdir $os"
        echo "... to produce $spackdir/etc/spack/`uname -s | tr [A-Z] [a-z]`/$os/packages.yaml"
        ./fermi-spack-tools/bin/make_packages_yaml $spackdir $os
    fi

    includecount=`grep -c "linux/$os" $spackdir/etc/spack/include.yaml`
    if [ $includecount -eq 0 ]; then
      echo "Adding linux/$os to $spackdir/etc/spack/include.yaml"
      cat >> "$spackdir/etc/spack/include.yaml" <<-EOF

  # $os Packages
  - path: "$spack/etc/spack/linux/$os"
    optional: true
    when: 'os == "$os"'

EOF
    fi

    mkdir spack-repos 2>/dev/null;cd spack-repos

    repo_found=`spack repo list|grep -c spack-repos/spack-packages`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: spack-packages (builtin)"
        git clone https://github.com/art-daq/spack-packages.git -b artdaq/Spack1.1
        spack repo add ./spack-packages/repos/spack_repo/builtin
    else
        cd spack-packages && git checkout artdaq/Spack1.1 && git pull; cd $Base/spack-repos
    fi

    repo_found=`spack repo list|grep -c spack-repos/fnal_art`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: fnal_art"
        git clone https://github.com/art-daq/fnal_art.git
        cd fnal_art && git checkout artdaq/Spack1.1 ; cd $Base/spack-repos
        spack repo add ./fnal_art/spack_repo/fnal_art
    else
        cd fnal_art && git fetch -a && git checkout artdaq/Spack1.1 ; cd $Base/spack-repos
    fi

    repo_found=`spack repo list|grep -c spack-repos/scd_recipes`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: scd_recipes"
        git clone https://github.com/fnal-fife/scd_recipes.git
        cd scd_recipes && git checkout cb5246e9f679b69a0c3037b67b22d7990043d11a ; cd $Base/spack-repos
        spack repo add ./scd_recipes/spack_repo/scd_recipes
    else
        cd scd_recipes && git fetch -a && git checkout cb5246e9f679b69a0c3037b67b22d7990043d11a ; cd $Base/spack-repos
    fi

    repo_found=`spack repo list|grep -c spack-repos/artdaq-spack`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: artdaq-spack"
        git clone https://github.com/art-daq/artdaq-spack.git -b artdaq/Spack1.1
        spack repo add ./artdaq-spack/spack_repo/artdaq_spack
    else
        cd artdaq-spack && git checkout artdaq/Spack1.1 && git pull; cd $Base/spack-repos
    fi

    repo_found=`spack repo list|grep -c spack-repos/mu2e-spack`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: mu2e-spack"
        git clone https://github.com/Mu2e/mu2e-spack.git -b artdaq/Spack1.1
        spack repo add ./mu2e-spack/spack_repo/mu2e_spack
    else
        cd mu2e-spack && git checkout artdaq/Spack1.1 && git pull; cd ${Base}/spack-repos
    fi
    cd $Base

    spack config --scope=site add "config:extensions:- $Base/spack-mpd"

    if [ $opt_padding -eq 1 ];then
      spack config --scope=site add config:install_tree:padded_length:255
    fi
}

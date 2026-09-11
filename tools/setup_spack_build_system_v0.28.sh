function install_spack_build_system()
{
    Base=$1
    spackdir=$2
    opt_padding=${3:-0}

    if ! [ -d $spackdir ];then
        $(
        cd ${spackdir%/spack}
        git clone https://github.com/art-daq/spack.git -b artdaq/Spack0.28
            )
    else
        cd $spackdir && git checkout artdaq/Spack0.28 && git pull ; cd $Base
    fi

    cat >setup-env.sh <<-EOF
export SPACK_DISABLE_LOCAL_CONFIG=true
export SPACK_USER_CACHE_PATH=$Base/.spack-cache
source $spackdir/share/spack/setup-env.sh
EOF

    source setup-env.sh

    if ! [ -d fermi-spack-tools ]; then
        git clone https://github.com/art-daq/fermi-spack-tools.git -b artdaq/Spack0.28
    else
        cd fermi-spack-tools && git checkout artdaq/Spack0.28 && git pull ; cd $Base
    fi
    if ! [ -d spack-mpd ]; then
        git clone https://github.com/art-daq/spack-mpd.git -b artdaq/Spack0.28
    else
        cd spack-mpd && git checkout artdaq/Spack0.28 && git pull; cd $Base
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

    mkdir spack-repos 2>/dev/null;cd spack-repos

    repo_found=`spack repo list|awk '{print $1}'|grep -c fnal_art`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: fnal_art"
        git clone https://github.com/art-daq/fnal_art.git
        cd fnal_art && git checkout artdaq/Spack0.28 ; cd ..
        spack repo add ./fnal_art
    else
        cd fnal_art && git fetch -a && git checkout artdaq/Spack0.28 ; cd ..
    fi

    repo_found=`spack repo list|awk '{print $1}'|grep -c scd_recipes`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: scd_recipes"
        git clone https://github.com/fnal-fife/scd_recipes.git
        cd scd_recipes && git checkout e9c8cc8af792008c3c85724cc8ae3ee0662233d6 ; cd ..
        rm -rf scd_recipes/packages/perl-ipc-run3
        spack repo add ./scd_recipes
    else
        cd scd_recipes && git fetch -a && git checkout e9c8cc8af792008c3c85724cc8ae3ee0662233d6 ; cd ..
        rm -rf scd_recipes/packages/perl-ipc-run3
    fi

    repo_found=`spack repo list|awk '{print $1}'|grep -c artdaq-spack`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: artdaq-spack"
        git clone https://github.com/art-daq/artdaq-spack.git -b artdaq/Spack0.28
        spack repo add ./artdaq-spack
    else
        cd artdaq-spack && git checkout artdaq/Spack0.28 && git pull; cd $Base/spack-repos
    fi

    repo_found=`spack repo list|awk '{print $1}'|grep -c mu2e-spack`
    if [ $repo_found -eq 0 ]; then
        echo "Adding repo: mu2e-spack"
        git clone https://github.com/Mu2e/mu2e-spack.git -b artdaq/Spack0.28
        spack repo add ./mu2e-spack
    else
        cd mu2e-spack && git checkout artdaq/Spack0.28 && git pull; cd ${Base}/spack-repos
    fi
    cd $Base

    spack config --scope=site add "config:extensions:- $Base/spack-mpd"

    if [ $opt_padding -eq 1 ];then
      spack config --scope=site add config:install_tree:padded_length:255
    fi
}

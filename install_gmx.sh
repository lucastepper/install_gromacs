#! /usr/bin/env bash

# Get gromacs version, if using cuda and mpi from cmd line
GMX_VERSION=$1
DEBIAN_VERSION=$2
NUM_CORES=7
# Check that version is either year, or year.\d
(echo $GMX_VERSION | grep -P "^[0-9]{4}(.[0-9])?") || (echo "Invalid VERSION format = $GMX_VERSION" >&2; exit 1)
echo "Installing gromacs version $GMX_VERSION"

# Check if cuda in argvs at place 2 to 10
INSTALL_DIR_BASE="/net/opt/gromacs"
INSTALL_DIR_FOR_VERSION="$DEBIAN_VERSION"
BUILD_STR="cmake $(pwd)/gromacs_builds/downloads/gromacs-${GMX_VERSION} -DGMX_BUILD_OWN_FFTW=ON -DREGRESSIONTEST_DOWNLOAD=OFF -DGMX_MPI=off "

if [[ " $* " == *" double "* ]]; then
    DOUBLE="true"
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/double"
    BUILD_STR="$BUILD_STR -DGMX_DOUBLE=on "
else
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/single"
    BUILD_STR="$BUILD_STR -DGMX_DOUBLE=off "
fi
if [[ " $* " == *" cuda "* ]]; then
    if [[ "$DOUBLE" == "true" ]]; then
        echo "cuda and double can't both be true" >&2
        exit 1
    fi
    CUDA="true"
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/cuda"
    BUILD_STR="$BUILD_STR -DGMX_GPU=CUDA "
fi
if (! [[ $CUDA == "true" ]]) && (! [[ $DOUBLE == "true" ]]); then
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/cpu"
fi
if [[ " $* " == *" mpi "* ]]; then
    MPI="true"
    INSTALL_DIR_FOR_VERSION=$(echo $INSTALL_DIR_FOR_VERSION | sed s'/gromacs/gromacs-mpi/'g)
fi
if [[ " $* " == *" plumed"* ]]; then
    PLUMED="true"
    BUILD_STR=$(echo $BUILD_STR | sed s'/gromacs-/gromacs-plumed-/'g)
    PLUMED_VERSION=$(echo " $* " | grep -oP "plumed=(\d+[\d.]*)" | tr -d "plumed=")
    PLUMED_LINK="https://github.com/plumed/plumed2/releases/download/v${PLUMED_VERSION}/plumed-${PLUMED_VERSION}.tgz"
fi
# Add version number
INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/$GMX_VERSION"

# check for avx versions
if [[ " $* " == *" AVX_256 "* ]]; then
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/AVX_256"
    BUILD_STR="$BUILD_STR -DGMX_SIMD=AVX_256 "
elif [[ " $* " == *" AVX2_256 "* ]]; then
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/AVX2_256"
    BUILD_STR="$BUILD_STR -DGMX_SIMD=AVX2_256 "
elif [[ " $* " == *" AVX_512 "* ]]; then
    INSTALL_DIR_FOR_VERSION="$INSTALL_DIR_FOR_VERSION/AVX_512"
    BUILD_STR="$BUILD_STR -DGMX_SIMD=AVX_512 "
else
    echo -e "Please choose one of 'AVX_256', 'AVX2_256', 'AVX_512' as SIMD."
    exit 1
fi

echo $PLUMED
echo $PLUMED_VERSION
echo $INSTALL_DIR_FOR_VERSION
PLUMED_FILE="plumed-${PLUMED_VERSION}.tgz"
BUILD_DIR="$(pwd)/gromacs_builds/gromacs-${GMX_VERSION}/${INSTALL_DIR_FOR_VERSION}"
DOWNLOAD_DIR="$(pwd)/gromacs_builds/downloads"
INSTALL_DIR="${INSTALL_DIR_BASE}/${INSTALL_DIR_FOR_VERSION}"
if [[ "$PLUMED" == "true" ]]; then
    BUILD_DIR="$(pwd)/gromacs_builds/gromacs-plumed-${GMX_VERSION}/${INSTALL_DIR_FOR_VERSION}"
    INSTALL_DIR=$(echo $INSTALL_DIR | sed s'/gromacs/gromacs-plumed/'g)
    INSTALL_DIR_PLUMED="/net/opt/plumed/plumed-$PLUMED_VERSION"
fi
BUILD_STR="$BUILD_STR -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR "
echo $BUILD_STR

if [[ -d $INSTALL_DIR ]]; then
    echo "INSTALL dir: $INSTALL_DIR already exitsts, skipping."
    exit 0
fi
echo "Building to $BUILD_DIR"
echo "Installing to $INSTALL_DIR"

sleep 4

if [[ "$PLUMED" == "true" ]]; then
    echo "Installing plumed to $INSTALL_DIR_PLUMED"
fi
if ! [[ -d $BUILD_DIR ]]; then
    mkdir -p $BUILD_DIR
fi
if ! [[ -d $DOWNLOAD_DIR ]]; then
    mkdir -p $DOWNLOAD_DIR
fi

# download file if not there
cd "$DOWNLOAD_DIR"
FILE="gromacs-${GMX_VERSION}.tar.gz"
if ! [[ -f $FILE ]]; then
    wget --continue "ftp://ftp.gromacs.org/gromacs/$FILE"
    # check if we are looking for mayor version, which could be $year, we parse to $year.0
    if ! [[ -f $FILE ]] &&  [[ $(echo $GMX_VERSION | grep -oP "\.0") == ".0" ]]; then
        GMX_VERSION_NEW=$(echo $GMX_VERSION | sed s'/\.0//'g)
        FILE_NEW="gromacs-${GMX_VERSION_NEW}.tar.gz"
        wget --continue "ftp://ftp.gromacs.org/gromacs/$FILE_NEW"
        tar -xf $FILE_NEW
        mv -v $DOWNLOAD_DIR/$GMX_VERSION_NEW $DOWNLOAD_DIR/$GMX_VERSION
        sleep 2
    else
        tar -xf $FILE
    fi
fi
if [[ "$PLUMED" == "true" ]]; then
    if ! [[ -f $PLUMED_FILE ]]; then
        wget --continue "https://github.com/plumed/plumed2/releases/download/v2.10.0/$PLUMED_FILE"
        tar -zxvf $PLUMED_FILE
    fi
fi


# make plumed first if needed
if [[ "$PLUMED" == "true" ]]; then
    # building plumed somewhere other then in download folder did not work.
    if ! [[ -d $INSTALL_DIR_PLUMED ]]; then
        cd plumed-$PLUMED_VERSION
        ./configure --prefix=$INSTALL_DIR_PLUMED
        make -j $NUM_CORES
        make install
        # make module file
        cp $INSTALL_DIR_PLUMED/lib/plumed/modulefile /net/opt/modulefiles/bookworm/plumed/$PLUMED_VERSION
    fi
    echo""; echo "Loading plumed"
    source /etc/profile
    module load plumed/$PLUMED_VERSION || (echo "Could not load plumed"; exit 1)
    which plumed

    echo""; echo "Copying gmx source code"
    # if we build with plumed, we should generate a copy of the source files before patching
    GMX_COPY_FOR_PLUMED=$DOWNLOAD_DIR/gromacs-plumed-$GMX_VERSION
    if ! [[ -d $GMX_COPY_FOR_PLUMED ]]; then
        rm -r $GMX_COPY_FOR_PLUMED
    fi
    cp -r $DOWNLOAD_DIR/gromacs-$GMX_VERSION $GMX_COPY_FOR_PLUMED
    cd $GMX_COPY_FOR_PLUMED
    echo""; echo "Patching gmx with plumed"
    pwd
    plumed patch -p --engine gromacs-$GMX_VERSION || (echo "Could not patch gmx with plumed"; exit 1)
fi


sleep 3
echo""; echo "Building gmx"
# make build dir, go there, build, install
cd $BUILD_DIR
rm -r build
mkdir build
cd build
eval $BUILD_STR
make -j $NUM_CORES
make install

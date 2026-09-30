#! /usr/bin/bash

gmx_version=$1
plumed_version=$2
debian_version=$(lsb_release -c | tail -n 1 | awk '{print $2}')

echo "Debian: $debian_version"
if [[ -z "$gmx_version" ]] ; then
    echo "Provide gromacs_version as first argument"
    exit 1
fi

for cpu_or_cuda in {"cpu","cuda"}; do
    for simd in {"AVX_256","AVX2_256","AVX_512"}; do
        if [[ " $* " == *" plumed"* ]]; then
            bash install_gmx.sh $gmx_version $debian_version single $cpu_or_cuda $simd $plumed_version
        else
            bash install_gmx.sh $gmx_version $debian_version single $cpu_or_cuda $simd
        fi
    done
done
bash copy_modulefiles.sh $gmx_version $debian_version $plumed_version

if [[ " $* " == *" double"* ]]; then
    for simd in {"AVX_256","AVX2_256","AVX_512"}; do
        bash install_gmx.sh $gmx_version double $simd
    done
fi

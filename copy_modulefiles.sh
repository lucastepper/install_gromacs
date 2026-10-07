#! /usr/bin/bash

gmx_version=$1
debian_version=$2
plumed_version=$3
gcc_module=$4
if [[ -z "$gmx_version" ]] ; then
    echo "Provide gromacs_version as first argument"
    exit 1
fi
if [[ -z "$debian_version" ]] ; then
    echo "Provide debian_version as second argument"
    exit 1
fi

if [[ " $* " == *" plumed"* ]]; then
    base_dir="/net/opt/modulefiles/bookworm/gromacs-plumed"
    plumed="true"
else
    base_dir="/net/opt/modulefiles/bookworm/gromacs"
    plumed="false"
fi

for cpu_or_cuda in {"cpu","cuda"}; do
    dest="$base_dir/single/$cpu_or_cuda/$gmx_version"
    /usr/bin/cp -v module_file_template.tcl $dest
    if [[ $plumed == "true" ]];  then
        echo "Adding plumed version: $plumed_version to module file"
        sed -i s'/PLUMEDVERSION/$plumed_version/'g $dest
    fi
    if ! [[ -z $gcc_module ]];  then
        echo "Adding gcc module dependency"
        sed -i "0,/module-whatis/s//module load ${gcc_module}\n\nmodule-whatis/" $dest
    fi
done
if [[ " $* " == *" double"* ]]; then
    /usr/bin/cp -v module_file_template.tcl $base_dir/double/$gmx_version
fi
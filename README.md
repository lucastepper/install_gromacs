# GROMACS installation scripts

This project installs different GROMACS configurations and generates Tcl module files for them.

## Main workflow

Install a GROMACS version with Spack:

```bash
./install_spack_gmx_all.sh <version> [spack-install-options]
```

For example, `./install_spack_gmx_all.sh 2026.4` installs CPU-only and CUDA-enabled GROMACS builds for AVX_256, AVX2_256, AVX_512, and Zen 2 targets.  Extra arguments are passed to every `spack install` command.  The script records the hashes of successful builds in `gromacs-<version>-hashes.txt`.

Then generate the module files:

```bash
./create_spack_gmx_module.sh <version>
```

This finds the installed Spack packages and creates CPU and CUDA Tcl modulefiles under `/net/opt/modulefiles`.  The generated modules select a compatible installed architecture for the current CPU.

## Auxiliary scripts

`add_spack_package_version.sh` adds an upstream version to a package in the local Spack package repository.  It derives the archive URL, downloads it, calculates its SHA-256 checksum, and inserts the version declaration:

```bash
./add_spack_package_version.sh <package> <version>
```

`augment_plumed_patch_spack.sh` augments Spack's PLUMED package so more GROMACS versions can be patched with PLUMED:

```bash
./augment_plumed_patch_spack.sh
```

It replaces PLUMED's `apply_patch` method with the implementation in `plumed_apply_patch.py` and installs `plumed_patch_overrides.conf` alongside the Spack PLUMED package.  Add version-to-supported-engine mappings to that configuration when needed.

## Legacy installer

`install_gmx_all.sh` is the legacy Bash-based GROMACS installer.  It builds the CPU/CUDA SIMD variants directly through `install_gmx.sh` and copies modulefile templates with `copy_modulefiles.sh`; the Spack workflow above is the preferred approach.

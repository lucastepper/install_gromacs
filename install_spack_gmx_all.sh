#!/usr/bin/env bash

# Install CPU-optimized GROMACS variants, with and without CUDA, through Spack.
set -euo pipefail

if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    COLOR_RESET=$'\033[0m'
else
    GREEN=""
    RED=""
    COLOR_RESET=""
fi

# Arguments after GROMACSVERSION are additional constraints for every Spack spec.
SPACK_INSTALL_ARGS=("${@:2}")

if ! command -v spack >/dev/null 2>&1; then
    echo "spack must be available on PATH" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
DEBIANVERSION="${VERSION_ID}"
DEBIANNAME="${VERSION_CODENAME}"

GROMACSVERSION="${1:-}"
if [[ -z "$GROMACSVERSION" ]]; then
    read -r -p "GROMACS version: " GROMACSVERSION
fi

if [[ -z "$GROMACSVERSION" ]]; then
    echo "GROMACS version cannot be empty" >&2
    exit 1
fi

declare -A gromacs_hashes
declare -a successful_builds
declare -a failed_builds
hash_file="${PWD}/gromacs-${GROMACSVERSION}-hashes.txt"

# Start a fresh record for this requested version. Only successful hash queries
# are recorded in this file.
: > "$hash_file"

# Zen 2 supports the same GROMACS AVX2_256 SIMD setting as Haswell.
declare -A architectures=(
    [AVX_256]="linux-debian${DEBIANVERSION}-ivybridge"
    [AVX2_256]="linux-debian${DEBIANVERSION}-haswell"
    [AVX_512]="linux-debian${DEBIANVERSION}-x86_64_v4"
    [ZEN2]="linux-debian${DEBIANVERSION}-zen2"
)

for cuda_variant in ~cuda +cuda; do
    for build in AVX_256 AVX2_256 AVX_512 ZEN2; do
        architecture="${architectures[$build]}"
        build_name="${build}_${cuda_variant#+}"
        echo "Installing ${build_name}: gromacs@${GROMACSVERSION} ~~mpi ~~double ${cuda_variant} arch=${architecture}"

        if spack install "gromacs@${GROMACSVERSION} ~~mpi ~~double ${cuda_variant} arch=${architecture}" "${SPACK_INSTALL_ARGS[@]}"; then
            if hash="$(spack python -c 'import spack.store; r=max(spack.store.STORE.db.query("gromacs", installed=True), key=lambda s: spack.store.STORE.db.get_record(s).installation_time); print(r.dag_hash())')"; then
                gromacs_hashes["$build_name"]="$hash"
                printf '%s=%s\n' "$build_name" "$hash" >> "$hash_file"
                successful_builds+=("$build_name")
            else
                failed_builds+=("${build_name} (hash query failed)")
            fi
        else
            failed_builds+=("${build_name} (install failed)")
        fi
    done
done

echo "Hash records written to: $hash_file"
printf '%sSuccessful builds (%s):%s\n' "$GREEN" "${#successful_builds[@]}" "$COLOR_RESET"
if ((${#successful_builds[@]})); then
    for build_name in "${successful_builds[@]}"; do
        printf '%s  %s%s\n' "$GREEN" "$build_name" "$COLOR_RESET"
    done
else
    printf '%s  none%s\n' "$GREEN" "$COLOR_RESET"
fi
printf '%sFailed builds (%s):%s\n' "$RED" "${#failed_builds[@]}" "$COLOR_RESET"
if ((${#failed_builds[@]})); then
    for build_name in "${failed_builds[@]}"; do
        printf '%s  %s%s\n' "$RED" "$build_name" "$COLOR_RESET"
    done
else
    printf '%s  none%s\n' "$RED" "$COLOR_RESET"
fi

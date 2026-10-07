#!/usr/bin/env bash

# Copy the Spack GROMACS module template for both CPU and CUDA installs.
set -euo pipefail

if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    GREEN_RESET=$'\033[0m'
else
    GREEN=""
    GREEN_RESET=""
fi
if [[ -t 2 ]]; then
    RED=$'\033[0;31m'
    RED_RESET=$'\033[0m'
else
    RED=""
    RED_RESET=""
fi

report_found() {
    printf '%sFound: %s%s\n' "$GREEN" "$*" "$GREEN_RESET"
}

report_error() {
    printf '%sError: %s%s\n' "$RED" "$*" "$RED_RESET" >&2
}

if ! command -v spack >/dev/null 2>&1; then
    report_error "spack must be available on PATH"
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
DEBIANNAME="${VERSION_CODENAME}"
module_root="/net/opt/modulefiles"

GROMACSVERSION="${1:-}"
if [[ -z "$GROMACSVERSION" ]]; then
    read -r -p "GROMACS version: " GROMACSVERSION
fi

if [[ -z "$GROMACSVERSION" ]]; then
    report_error "GROMACS version cannot be empty"
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
template="${script_dir}/module_file_template_spack.tcl"
if [[ ! -f "$template" ]]; then
    report_error "Module template not found: $template"
    exit 1
fi

spack_arch="$(spack arch)"
query_architecture_prefix="${spack_arch%-*}"
if [[ "$query_architecture_prefix" == "$spack_arch" ]]; then
    report_error "Could not derive the platform/OS prefix from: $spack_arch"
    exit 1
fi

# Spack queries retain their full platform/OS/target architecture, while the
# installation tree uses the new platform/target directory layout.
declare -A query_architectures=(
    [1]="${query_architecture_prefix}-ivybridge"
    [2]="${query_architecture_prefix}-haswell"
    [3]="${query_architecture_prefix}-x86_64_v4"
    [4]="${query_architecture_prefix}-zen2"
)
declare -A install_architectures=(
    [1]="linux-ivybridge"
    [2]="linux-haswell"
    [3]="linux-x86_64_v4"
    [4]="linux-zen2"
)

escape_sed() {
    sed 's/[\\&@]/\\&/g' <<< "$1"
}

find_gromacs_install() {
    local cuda_variant="$1"
    local architecture="$2"
    local spec="gromacs@${GROMACSVERSION}${cuda_variant}~plumed~mpi"
    local find_output line hash ignored
    local -a hashes=()

    FOUND_HASH=""

    if ! find_output="$(spack find -L "$spec" "arch=${architecture}")"; then
        report_error "Spack query failed for ${spec} arch=${architecture}"
        return 2
    fi

    while IFS= read -r line; do
        read -r hash ignored <<< "$line"
        if [[ ${#hash} -eq 32 && "$hash" =~ ^[a-z0-9]+$ ]]; then
            hashes+=("$hash")
        fi
    done <<< "$find_output"

    case ${#hashes[@]} in
        0)
            return 1
            ;;
        1)
            FOUND_HASH="${hashes[0]}"
            report_found "${spec} arch=${architecture} (${FOUND_HASH})"
            ;;
        *)
            report_error "${#hashes[@]} GROMACS packages match ${spec} arch=${architecture}: ${hashes[*]}"
            return 2
            ;;
    esac

}

check_install_paths() {
    local architecture="$1"
    local hash="$2"
    local cuda_or_cpu="$3"
    local install_root="/net/opt/spack_ag_netz/spack_${DEBIANNAME}/opt/spack/${architecture}/gromacs-${GROMACSVERSION}-${hash}"
    local variable relative_path
    local missing_paths=0

    while IFS=: read -r variable relative_path; do
        if [[ ! -e "${install_root}/${relative_path}" ]]; then
            report_error "${cuda_or_cpu} ${architecture} ${variable} path does not exist: ${install_root}/${relative_path}"
            missing_paths=1
        fi
    done <<'EOF'
PATH:bin
MANPATH:share/man
PKG_CONFIG_PATH:lib/pkgconfig
CMAKE_PREFIX_PATH:.
EOF

    return "$missing_paths"
}

timestamp="$(date --iso-8601=seconds)"
version_escaped="$(escape_sed "$GROMACSVERSION")"
timestamp_escaped="$(escape_sed "$timestamp")"
debian_name_escaped="$(escape_sed "$DEBIANNAME")"
module_errors=0

for cuda_or_cpu in cpu cuda; do
    module_file="${module_root}/${DEBIANNAME}/gromacs/single/${cuda_or_cpu}/${GROMACSVERSION}"
    mkdir -p "$(dirname -- "$module_file")"
    cp "$template" "$module_file"

    sed -i \
        -e "s@|VERSION|@${version_escaped}@g" \
        -e "s@|TIMESTAMP|@${timestamp_escaped}@g" \
        -e "s@|DEBIANNAME|@${debian_name_escaped}@g" \
        "$module_file"

    if [[ "$cuda_or_cpu" == cuda ]]; then
        cuda_variant="+cuda"
    else
        cuda_variant="~cuda"
    fi

    for index in 1 2 3 4; do
        query_architecture="${query_architectures[$index]}"
        install_architecture="${install_architectures[$index]}"
        if find_gromacs_install "$cuda_variant" "$query_architecture"; then
            hash="$FOUND_HASH"
            arch_escaped="$(escape_sed "$install_architecture")"
            hash_escaped="$(escape_sed "$hash")"
            sed -i \
                -e "s@|ARCH${index}|@${arch_escaped}@g" \
                -e "s@|HASH${index}|@${hash_escaped}@g" \
                "$module_file"

            if ! check_install_paths "$install_architecture" "$hash" "$cuda_or_cpu"; then
                module_errors=1
            fi
        else
            status=$?
            if ((status == 2)); then
                module_errors=1
            fi
        fi
    done

    echo "Created module file: $module_file"
done

exit "$module_errors"

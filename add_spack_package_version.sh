#!/usr/bin/env bash

package=$1
version=$2
package_file=$(find "$HOME/.spack/package_repos" -path "*/repos/spack_repo/builtin/packages/$package/package.py" -type f -print -quit)

if [[ -z $package || -z $version || ! -f $package_file ]]; then
    echo "Usage: $0 PACKAGE VERSION" >&2
    exit 1
fi

url=$(sed -n 's/^[[:space:]]*url = "\(.*\)"/\1/p' "$package_file" | head -n 1)
old_version=$(printf '%s\n' "$url" | grep -oE '[0-9]+(\.[0-9]+)+' | head -n 1)
if [[ -z $url || -z $old_version ]]; then
    echo "Could not determine download URL from $package_file" >&2
    exit 1
fi

url=${url/$old_version/$version}
archive=/tmp/$package-$version.tar.gz
curl -L "$url" -o "$archive" || exit 1
sha256=$(sha256sum "$archive" | awk '{print $1}')

sed -i "/^[[:space:]]*version(\"[0-9]/i\    version(\"$version\", sha256=\"$sha256\")" "$package_file"

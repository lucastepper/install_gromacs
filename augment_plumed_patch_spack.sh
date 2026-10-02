#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PACKAGE_FILE=$(find "$HOME/.spack/package_repos" -path "*/repos/spack_repo/builtin/packages/plumed/package.py" -type f -print -quit)

if [[ -z $PACKAGE_FILE ]]; then
    echo "Could not find Spack's PLUMED package.py" >&2
    exit 1
fi

python3 - "$PACKAGE_FILE" "$SCRIPT_DIR/plumed_apply_patch.py" <<'PY'
import ast
import sys
from pathlib import Path

package_file = Path(sys.argv[1])
function_file = Path(sys.argv[2])
package_source = package_file.read_text()
function_source = function_file.read_text()

function = next(
    node for node in ast.parse(function_source).body
    if isinstance(node, ast.FunctionDef) and node.name == "apply_patch"
)
plumed_class = next(
    node for node in ast.parse(package_source).body
    if isinstance(node, ast.ClassDef) and node.name == "Plumed"
)
old_function = next(
    node for node in plumed_class.body
    if isinstance(node, ast.FunctionDef) and node.name == "apply_patch"
)

replacement = "\n".join(
    "    " + line if line else line for line in function_source.splitlines()
) + "\n"
lines = package_source.splitlines(keepends=True)
lines[old_function.lineno - 1 : old_function.end_lineno] = [replacement]
package_file.write_text("".join(lines))
PY
if [[ ! -f "$(dirname "$PACKAGE_FILE")/plumed_patch_overrides.conf" ]]; then
    cp "$SCRIPT_DIR/plumed_patch_overrides.conf" "$(dirname "$PACKAGE_FILE")/"
fi

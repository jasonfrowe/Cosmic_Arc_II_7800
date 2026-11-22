#!/bin/sh
# Build Cosmic Arc II with the vendored 7800basic (needs wasmtime on the PATH).
#
#   tools/build.sh   -> build/cosmicarc.a78
#
# 7800basic writes its intermediate files next to the source, so the build
# runs in a copy of src/ under build/work and copies the results out.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASDIR="$ROOT/tools/7800basic"
WORK="$ROOT/build/work"

python3 "$ROOT/tools/music.py"
python3 "$ROOT/tools/planet.py"

rm -rf "$WORK"
mkdir -p "$WORK"
cp -R "$ROOT/src/." "$WORK/"
# 7800basic turns an inline file's path into a symbol name, so a "/" in
# it breaks the assembly: assembly files go flat into the work directory.
cp "$ROOT"/src/asm/*.asm "$ROOT"/src/gen/*.asm "$WORK/"

cd "$WORK"
bas7800dir="$BASDIR" PATH="$BASDIR:$PATH" sh "$BASDIR/7800basic.sh" cosmicarc.bas > build.log 2>&1 || true
if [ ! -f cosmicarc.bas.a78 ] || grep -q -i -E "error|unresolved|Compilation failed" build.log; then
    grep -i -E -B2 -A2 "error|unresolved|failed" build.log | head -60
    echo "BUILD FAILED (full log: build/work/build.log)"
    exit 1
fi
python3 "$ROOT/tools/a78header.py" cosmicarc.bas.a78 "$ROOT/build/cosmicarc.a78"
cp cosmicarc.bas.bin "$ROOT/build/cosmicarc.bin"
grep -E "bytes of ROM space left|used as zone memory|bytes left in the 7800basic reserved area" build.log || true
echo "built build/cosmicarc.a78"

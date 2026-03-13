#!/bin/bash
# Extract and render digraphs from markdown files
# Usage: render-digraphs.sh <markdown-file> <output-dir>
# Requires: graphviz (brew install graphviz)

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <markdown-file> <output-dir>"
    echo "Example: $0 SKILL.md ./diagrams"
    exit 1
fi

INPUT="$1"
OUTDIR="$2"

if [ ! -f "$INPUT" ]; then
    echo "Error: File not found: $INPUT"
    exit 1
fi

if ! command -v dot &> /dev/null; then
    echo "Error: graphviz not installed. Run: brew install graphviz"
    exit 1
fi

mkdir -p "$OUTDIR"

# Extract digraphs using awk (portable across macOS/Linux)
awk '
/^```dot$/ { capture=1; graphnum++; next }
/^```$/ { if(capture) { capture=0 } next }
capture { print > (OUTDIR "/graph" graphnum ".dot") }
' OUTDIR="$OUTDIR" "$INPUT"

# Count extracted graphs
count=$(ls -1 "$OUTDIR"/*.dot 2>/dev/null | wc -l | tr -d ' ')

if [ "$count" -eq 0 ]; then
    echo "No digraphs found in $INPUT"
    exit 0
fi

# Render each to PNG
for f in "$OUTDIR"/*.dot; do
    dot -Tpng "$f" -o "${f%.dot}.png"
done

echo "Rendered $count digraph(s) to $OUTDIR/"
ls -1 "$OUTDIR"/*.png

# Open in Preview (macOS)
if [ "$(uname)" = "Darwin" ]; then
    open "$OUTDIR"/*.png
fi

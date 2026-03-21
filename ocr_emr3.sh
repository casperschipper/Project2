#!/usr/bin/env bash
# OCR script for Electronic-Music-Reports-3.pdf
# Typewritten/scanned document — uses Tesseract with settings tuned for that.
#
# TWEAKABLE SETTINGS
# ==================
PDF="/Users/casperschipper/devel/ocaml/PR2/Projekt2/manuals and notes/Electronic-Music-Reports-3.pdf"
OUTDIR="/Users/casperschipper/devel/ocaml/PR2/Projekt2/ocr_output"
LANG="eng"           # Tesseract language(s), e.g. "eng" or "eng+deu"
DPI=400              # Higher = better quality but slower (300 is minimum, 400 recommended for typewriter)
PSM=6                # Page segmentation mode: 6 = uniform block of text (good for typewriter pages)
                     # Other options: 3 = fully automatic, 4 = single column, 12 = sparse text
OEM=1                # OCR engine mode: 1 = LSTM only (best), 0 = legacy, 3 = both
START_PAGE=1         # First page to process (1-indexed)
END_PAGE=162         # Last page to process (set to "" to process all)
COMBINE=true         # Combine all pages into a single output file at the end
# ==================

set -euo pipefail

PDF_BASENAME=$(basename "$PDF" .pdf)
IMGDIR="$OUTDIR/pages_png"
TXTDIR="$OUTDIR/pages_txt"
COMBINED="$OUTDIR/${PDF_BASENAME}_ocr.txt"

echo "=== OCR: $PDF_BASENAME ==="
echo "DPI=$DPI  PSM=$PSM  OEM=$OEM  LANG=$LANG"
echo "Pages: ${START_PAGE}–${END_PAGE:-end}"
echo ""

mkdir -p "$IMGDIR" "$TXTDIR"

# Step 1: Convert PDF pages to PNG images via Ghostscript
echo "[1/3] Rendering PDF pages to PNG at ${DPI} dpi..."

FIRST=$((START_PAGE - 1))  # Ghostscript -dFirstPage is 1-indexed but we calc range
LAST="${END_PAGE:-}"

GS_ARGS=(
  -dBATCH -dNOPAUSE -q
  -sDEVICE=pngmono          # monochrome PNG — sharper for typewriter text
  -r"${DPI}"
  -dFirstPage="${START_PAGE}"
)
[[ -n "$LAST" ]] && GS_ARGS+=(-dLastPage="${LAST}")
GS_ARGS+=(
  "-sOutputFile=${IMGDIR}/page_%04d.png"
  "$PDF"
)

gs "${GS_ARGS[@]}"
echo "  Done. $(ls "$IMGDIR"/page_*.png | wc -l | tr -d ' ') images written to $IMGDIR"

# Step 2: Run Tesseract on each image
echo ""
echo "[2/3] Running Tesseract OCR..."

PAGES=("$IMGDIR"/page_*.png)
TOTAL=${#PAGES[@]}
COUNT=0

for IMG in "${PAGES[@]}"; do
  BASE=$(basename "$IMG" .png)
  OUTTXT="$TXTDIR/$BASE"
  if [[ -f "${OUTTXT}.txt" ]]; then
    echo "  skip $BASE (already done)"
  else
    COUNT=$((COUNT + 1))
    printf "  [%d/%d] %s\r" "$COUNT" "$TOTAL" "$BASE"
    tesseract "$IMG" "$OUTTXT" \
      -l "$LANG" \
      --oem "$OEM" \
      --psm "$PSM" \
      quiet 2>/dev/null
  fi
done
echo ""
echo "  Done. OCR text in $TXTDIR"

# Step 3: Combine into one file
if [[ "$COMBINE" == "true" ]]; then
  echo ""
  echo "[3/3] Combining pages into $COMBINED ..."
  {
    for TXT in "$TXTDIR"/page_*.txt; do
      PAGE=$(basename "$TXT" .txt | sed 's/page_0*//')
      echo "===== Page $PAGE ====="
      cat "$TXT"
      echo ""
    done
  } > "$COMBINED"
  echo "  Done. Combined output: $COMBINED"
  echo "  Size: $(wc -c < "$COMBINED" | tr -d ' ') bytes, $(wc -l < "$COMBINED" | tr -d ' ') lines"
fi

echo ""
echo "=== Finished ==="

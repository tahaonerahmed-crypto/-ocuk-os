#!/usr/bin/env bash
# =============================================================================
# 05-checksum.sh <iso-yolu>
# Verilen ISO icin <iso>.sha256 dosyasi uretir.
# Generates a <iso>.sha256 file for the given ISO.
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

ISO="${1:?Kullanim: $0 <iso-dosyasi> / Usage: $0 <iso-file>}"
require_file "$ISO"

OUT="${ISO}.sha256"
log_info "SHA256 hesaplaniyor / Computing SHA256 for: $ISO"
( cd "$(dirname "$ISO")" && sha256sum "$(basename "$ISO")" ) > "$OUT" \
    || die "SHA256 hesaplanamadi / Failed to compute SHA256"

log_ok "Checksum dosyasi olusturuldu / Checksum file created: $OUT"
cat "$OUT"

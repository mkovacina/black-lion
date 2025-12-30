#!/usr/bin/env bash
set -euo pipefail

# Export specific Apple Messages conversations (by handle) + useful attachments.
#
# Usage:
#   ./imessage-extractor.sh -o OUTPUT_DIR HANDLE [HANDLE...]
# Example:
#   ./imessage-extractor.sh -o ~/Desktop/imsg_backup "+12165551212" "someone@example.com"
#
# Notes:
# - Terminal needs Full Disk Access to read ~/Library/Messages
# - Close Messages.app to reduce "database is locked" risk
# - IMPORTANT: Messages uses SQLite WAL mode. Do NOT cp chat.db.
#   This script uses sqlite3 .backup to capture WAL contents safely.
# - macOS default bash is 3.2: this script avoids bash-4+ features.

OUT_DIR=""
DB="${HOME}/Library/Messages/chat.db"

usage() {
  cat <<EOF
Usage: $(basename "$0") -o OUTPUT_DIR HANDLE [HANDLE...]
Options:
  -o  Output directory (required)
  -d  Path to chat.db (optional; default: ~/Library/Messages/chat.db)

Example:
  $(basename "$0") -o ~/Desktop/imsg_backup "+12165551212" "person@email.com"
EOF
  exit 1
}

while getopts ":o:d:" opt; do
  case "$opt" in
    o) OUT_DIR="$OPTARG" ;;
    d) DB="$OPTARG" ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))

if [[ -z "${OUT_DIR}" || $# -lt 1 ]]; then usage; fi
if [[ ! -f "$DB" ]]; then
  echo "ERROR: Messages DB not found at: $DB"
  echo "Try: $(basename "$0") -d /path/to/chat.db -o OUTPUT_DIR HANDLE..."
  exit 2
fi

mkdir -p "$OUT_DIR"

# Temp DB copy via sqlite backup (captures WAL safely)
TMP_DB="$(mktemp -t chatdb.XXXXXX).db"
# Timeout helps if Messages has the DB busy
sqlite3 "$DB" ".timeout 5000" ".backup '$TMP_DB'"
trap 'rm -f "$TMP_DB"' EXIT

echo "Using DB backup: $TMP_DB"
echo "Output dir:      $OUT_DIR"
echo

sanitize() {
  echo "$1" | tr '/:@+ ' '_____' | tr -cd '[:alnum:]_-'
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Decide if an attachment is "useful" to copy.
# Returns 0 -> copy, 1 -> skip
is_useful_attachment() {
  local path="$1"
  local base ext ext_l ft

  base="$(basename "$path")"
  ext="${base##*.}"
  ext_l="$(lower "$ext")"

  # Skip common internal / metadata payloads
  case "$base" in
    pluginPayloadAttachment|pluginPayloadAttachment.*) return 1 ;;
    *_balloon_*|*balloon*|*Balloon*) return 1 ;;
    *_StickerCache*|*StickerCache*) return 1 ;;
    *_attributedBody*|*attributedBody*) return 1 ;;
  esac

  # Allowlist useful extensions (STRICT)
  case "$ext_l" in
    # images
    jpg|jpeg|png|gif|webp|heic|heif|tif|tiff|bmp) return 0 ;;
    # video
    mov|mp4|m4v|avi|mkv) return 0 ;;
    # audio
    mp3|m4a|aac|wav|aiff|flac) return 0 ;;
    # docs/text
    pdf|txt|rtf|html|htm|csv|json|xml) return 0 ;;
    doc|docx|xls|xlsx|ppt|pptx) return 0 ;;
    # archives
    zip|gz|tgz|rar|7z) return 0 ;;
    # contacts / calendar
    vcf|ics) return 0 ;;
    # misc
    svg) return 0 ;;
    *)
      ;;
  esac

  # If extension is missing/weird, sniff file content.
  ft="$(/usr/bin/file -b "$path" 2>/dev/null || true)"
  case "$ft" in
    *JPEG*|*PNG*|*HEIF*|*TIFF*|*GIF*|*Web/P*|*image*|\
    *QuickTime*|*MPEG*|*MP4*|*video*|\
    *audio*|*WAVE*|*AIFF*|*M4A*|\
    *PDF*|*Rich\ Text*|*HTML*|*text*|\
    *Zip\ archive*|*gzip\ compressed*|*7-zip*|*RAR*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

for HANDLE in "$@"; do
  SAFE_HANDLE="$(sanitize "$HANDLE")"
  THREAD_DIR="$OUT_DIR/$SAFE_HANDLE"
  mkdir -p "$THREAD_DIR/transcripts" "$THREAD_DIR/attachments"

  echo "== Exporting: $HANDLE =="

  # Find chat IDs that include this handle
  CHAT_IDS="$(sqlite3 -readonly "$TMP_DB" -batch -noheader "
    SELECT DISTINCT c.ROWID
    FROM chat c
    JOIN chat_handle_join chj ON chj.chat_id = c.ROWID
    JOIN handle h ON h.ROWID = chj.handle_id
    WHERE h.id = '$HANDLE';
  ")"

  if [[ -z "$CHAT_IDS" ]]; then
    echo "  No chats found for handle: $HANDLE"
    echo
    continue
  fi

  CHAT_IN="$(echo "$CHAT_IDS" | paste -sd, -)"

  CSV_OUT="$THREAD_DIR/transcripts/${SAFE_HANDLE}.csv"
  TXT_OUT="$THREAD_DIR/transcripts/${SAFE_HANDLE}.txt"

  # Export CSV transcript
  sqlite3 -readonly -header -csv "$TMP_DB" "
    WITH msgs AS (
      SELECT
        datetime((m.date/1000000000) + 978307200, 'unixepoch', 'localtime') AS local_time,
        CASE WHEN m.is_from_me = 1 THEN 'me' ELSE COALESCE(h.id,'(unknown)') END AS sender,
        COALESCE(
          NULLIF(m.text,''),
          CASE
            WHEN m.cache_has_attachments = 1 THEN '[ATTACHMENT]'
            WHEN m.associated_message_type IS NOT NULL AND m.associated_message_type != 0 THEN '[REACTION/TAPBACK]'
            WHEN m.attributedBody IS NOT NULL THEN '[RICH_TEXT(attributedBody)]'
            ELSE '[NON-TEXT MESSAGE]'
          END
        ) AS text,
        m.ROWID AS message_rowid,
        c.ROWID AS chat_rowid,
        c.display_name AS chat_name
      FROM message m
      JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
      JOIN chat c ON c.ROWID = cmj.chat_id
      LEFT JOIN handle h ON h.ROWID = m.handle_id
      WHERE c.ROWID IN ($CHAT_IN)
      ORDER BY m.date ASC
    )
    SELECT * FROM msgs;
  " > "$CSV_OUT"

  # Export simple text transcript
  {
    echo "Conversation export for: $HANDLE"
    echo "Exported at: $(date)"
    echo
    sqlite3 -readonly "$TMP_DB" "
      SELECT
        '[' || datetime((m.date/1000000000) + 978307200, 'unixepoch', 'localtime') || '] ' ||
        (CASE WHEN m.is_from_me = 1 THEN 'me' ELSE COALESCE(h.id,'(unknown)') END) || ': ' ||
        COALESCE(
          NULLIF(m.text,''),
          CASE
            WHEN m.cache_has_attachments = 1 THEN '[ATTACHMENT]'
            WHEN m.associated_message_type IS NOT NULL AND m.associated_message_type != 0 THEN '[REACTION/TAPBACK]'
            WHEN m.attributedBody IS NOT NULL THEN '[RICH_TEXT(attributedBody)]'
            ELSE '[NON-TEXT MESSAGE]'
          END
        )
      FROM message m
      JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
      JOIN chat c ON c.ROWID = cmj.chat_id
      LEFT JOIN handle h ON h.ROWID = m.handle_id
      WHERE c.ROWID IN ($CHAT_IN)
      ORDER BY m.date ASC;
    "
  } > "$TXT_OUT"

  echo "  Wrote transcript:"
  echo "    $CSV_OUT"
  echo "    $TXT_OUT"

  ATT_LIST="$THREAD_DIR/attachments/${SAFE_HANDLE}_attachments.tsv"
  SKIPPED_LIST="$THREAD_DIR/attachments/${SAFE_HANDLE}_skipped.tsv"

  # Build attachment list (ROWID + filename)
  sqlite3 -readonly -batch -noheader "$TMP_DB" "
    SELECT DISTINCT
      a.ROWID,
      a.filename
    FROM attachment a
    JOIN message_attachment_join maj ON maj.attachment_id = a.ROWID
    JOIN message m ON m.ROWID = maj.message_id
    JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
    JOIN chat c ON c.ROWID = cmj.chat_id
    WHERE c.ROWID IN ($CHAT_IN)
      AND a.filename IS NOT NULL;
  " | awk -F'|' '{print $1 "\t" $2}' > "$ATT_LIST"

  : > "$SKIPPED_LIST"

  COUNT_TOTAL=$(wc -l < "$ATT_LIST" | tr -d ' ')
  echo "  Found attachment references: $COUNT_TOTAL"

  COPIED=0
  MISSING=0
  SKIPPED=0

  while IFS=$'\t' read -r AROWID AFILENAME; do
    [[ -z "$AFILENAME" ]] && continue

    SRC="$AFILENAME"
    if [[ "$SRC" == "~/"* ]]; then
      SRC="${HOME}/${SRC:2}"
    fi

    if [[ ! -f "$SRC" ]]; then
      echo -e "${AROWID}\t${AFILENAME}\tMISSING" >> "$SKIPPED_LIST"
      MISSING=$((MISSING+1))
      continue
    fi

    if ! is_useful_attachment "$SRC"; then
      echo -e "${AROWID}\t${AFILENAME}\tFILTERED" >> "$SKIPPED_LIST"
      SKIPPED=$((SKIPPED+1))
      continue
    fi

    base="$(basename "$SRC")"
    dest="$THREAD_DIR/attachments/${AROWID}_${base}"
    cp -p "$SRC" "$dest"
    COPIED=$((COPIED+1))
  done < "$ATT_LIST"

  echo "  Copied:   $COPIED"
  echo "  Skipped:  $SKIPPED (filtered as not useful)"
  echo "  Missing:  $MISSING (referenced but not found on disk)"
  echo "  Attachment index: $ATT_LIST"
  echo "  Skipped log:      $SKIPPED_LIST"
  echo
done

echo "Done."
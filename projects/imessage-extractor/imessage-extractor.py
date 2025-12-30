#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.10"
# dependencies = ["pyobjc"]
# ///

import argparse
import csv
import datetime as dt
import re
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path
from typing import Optional

APPLE_EPOCH_UNIX = 978307200  # 2001-01-01 00:00:00 UTC in Unix seconds


def sanitize_name(s: str) -> str:
    s = (s or "").strip()
    s = s.replace("/", "_").replace(":", "_").replace("@", "_").replace("+", "_").replace(" ", "_")
    return re.sub(r"[^A-Za-z0-9_-]+", "_", s).strip("_") or "chat"


def apple_date_to_local_str(nanos_since_2001: Optional[int]) -> str:
    if nanos_since_2001 is None:
        return ""
    seconds = nanos_since_2001 / 1_000_000_000
    unix = seconds + APPLE_EPOCH_UNIX
    return dt.datetime.fromtimestamp(unix).strftime("%Y-%m-%d %H:%M:%S")


def try_import_foundation():
    try:
        import Foundation  # type: ignore
        return Foundation
    except Exception:
        return None


def decode_attributed_body(found: Optional[object], blob: Optional[bytes]) -> Optional[str]:
    """
    Decode Messages.attributedBody -> plain text (best effort).

    Supports:
      - typedstream (NSUnarchiver)  [your sample data]
      - keyed archive bplist (NSKeyedUnarchiver)
    """
    if blob is None or found is None:
        return None

    Foundation = found

    def extract_string(obj) -> Optional[str]:
        if obj is None:
            return None

        if hasattr(obj, "string"):
            try:
                s = str(obj.string())
                if s and s != "(null)":
                    return s
            except Exception:
                pass

        if isinstance(obj, str):
            return obj if obj else None

        if hasattr(obj, "count") and hasattr(obj, "objectAtIndex_"):
            try:
                n = int(obj.count())
                for i in range(n):
                    s = extract_string(obj.objectAtIndex_(i))
                    if s:
                        return s
            except Exception:
                pass

        if hasattr(obj, "allKeys") and hasattr(obj, "objectForKey_"):
            try:
                for k in obj.allKeys():
                    s = extract_string(obj.objectForKey_(k))
                    if s:
                        return s
            except Exception:
                pass

        try:
            s = str(obj)
            return s if s and s != "(null)" else None
        except Exception:
            return None

    def nsdata_from_bytes(b: bytes):
        return Foundation.NSData.dataWithBytes_length_(b, len(b))

    head = blob[:96]
    is_typedstream = (b"streamtyped" in head) or head.startswith(b"\x04\x0bstreamtyped")
    is_keyed = (b"bplist00" in head) or (b"bplist00" in blob[:4096])

    if is_typedstream:
        try:
            nsdata = nsdata_from_bytes(blob)
            obj = Foundation.NSUnarchiver.unarchiveObjectWithData_(nsdata)
            s = extract_string(obj)
            if s:
                return s
        except Exception:
            pass

    if is_keyed:
        try:
            idx = blob.find(b"bplist00")
            data_bytes = blob[idx:] if idx != -1 else blob
            nsdata = nsdata_from_bytes(data_bytes)
            obj = None
            try:
                obj = Foundation.NSKeyedUnarchiver.unarchiveObjectWithData_(nsdata)
            except Exception:
                obj = None
            s = extract_string(obj)
            if s:
                return s
        except Exception:
            pass

    # Last resort: attempt both
    try:
        nsdata = nsdata_from_bytes(blob)
        obj = Foundation.NSUnarchiver.unarchiveObjectWithData_(nsdata)
        s = extract_string(obj)
        if s:
            return s
    except Exception:
        pass

    try:
        nsdata = nsdata_from_bytes(blob)
        obj = Foundation.NSKeyedUnarchiver.unarchiveObjectWithData_(nsdata)
        s = extract_string(obj)
        if s:
            return s
    except Exception:
        pass

    return None


def copy_db_with_wal(src_db: Path) -> Path:
    """Copy chat.db + -wal/-shm to a temp dir so content in WAL isn't lost."""
    temp_dir = Path(tempfile.mkdtemp(prefix="imsg_db_"))
    dst_db = temp_dir / src_db.name
    shutil.copy2(src_db, dst_db)

    wal = src_db.with_name(src_db.name + "-wal")
    shm = src_db.with_name(src_db.name + "-shm")
    if wal.exists():
        shutil.copy2(wal, temp_dir / wal.name)
    if shm.exists():
        shutil.copy2(shm, temp_dir / shm.name)

    return dst_db


def is_useful_attachment(path: Path) -> bool:
    base = path.name
    lowered = base.lower()

    # Skip internal payloads
    if lowered.startswith("pluginpayloadattachment"):
        return False
    if "balloon" in lowered:
        return False
    if "stickercache" in lowered:
        return False
    if "attributedbody" in lowered:
        return False

    ext = path.suffix.lower().lstrip(".")
    allow = {
        "jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "tif", "tiff", "bmp",
        "mov", "mp4", "m4v", "avi", "mkv",
        "mp3", "m4a", "aac", "wav", "aiff", "flac",
        "pdf", "txt", "rtf", "html", "htm", "csv", "json", "xml",
        "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        "zip", "gz", "tgz", "rar", "7z",
        "vcf", "ics",
        "svg",
    }
    return ext in allow


def get_participants_for_chat(conn: sqlite3.Connection, chat_id: int) -> list[str]:
    rows = conn.execute(
        """
        SELECT DISTINCT COALESCE(h.id,'')
        FROM chat_handle_join chj
        JOIN handle h ON h.ROWID = chj.handle_id
        WHERE chj.chat_id = ?
        ORDER BY h.id
        """,
        (chat_id,),
    ).fetchall()
    participants = [r[0] for r in rows if r[0]]
    return participants


def export_single_chat(
    conn: sqlite3.Connection,
    base_dir: Path,
    chat_id: int,
    chat_display_name: str,
    foundation,
) -> None:
    participants = get_participants_for_chat(conn, chat_id)

    # Build stable, readable directory name
    if chat_display_name.strip():
        label = chat_display_name.strip()
    else:
        # Use a short participant-based label (first 3)
        short = participants[:3]
        label = " & ".join(short) if short else "chat"
        if len(participants) > 3:
            label += f" +{len(participants)-3}"

    safe_label = sanitize_name(label)
    chat_dir = base_dir / f"chat_{chat_id}_{safe_label}"
    (chat_dir / "attachments").mkdir(parents=True, exist_ok=True)

    csv_path = chat_dir / "transcript.csv"
    txt_path = chat_dir / "transcript.txt"

    rows = conn.execute(
        """
        SELECT
            m.date,
            m.is_from_me,
            COALESCE(h.id,'') AS sender_handle,
            m.text,
            m.attributedBody,
            m.cache_has_attachments,
            m.associated_message_type,
            m.ROWID AS message_rowid
        FROM message m
        JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
        LEFT JOIN handle h ON h.ROWID = m.handle_id
        WHERE cmj.chat_id = ?
        ORDER BY m.date ASC
        """,
        (chat_id,),
    ).fetchall()

    # Transcript
    with csv_path.open("w", newline="", encoding="utf-8") as fcsv, txt_path.open("w", encoding="utf-8") as ftxt:
        writer = csv.writer(fcsv)
        writer.writerow(["local_time", "sender", "text", "message_rowid"])

        ftxt.write(f"Chat ID: {chat_id}\n")
        if chat_display_name.strip():
            ftxt.write(f"Display name: {chat_display_name.strip()}\n")
        ftxt.write("Participants:\n")
        for p in participants:
            ftxt.write(f"  - {p}\n")
        ftxt.write(f"\nExported at: {dt.datetime.now():%Y-%m-%d %H:%M:%S}\n\n")

        for date, is_from_me, sender_handle, text, attributed, has_att, assoc, msg_id in rows:
            local_time = apple_date_to_local_str(date)
            sender = "me" if is_from_me == 1 else (sender_handle or "(unknown)")

            out_text = (text or "").strip()
            if not out_text:
                decoded = decode_attributed_body(foundation, attributed)
                if decoded:
                    out_text = decoded.strip()

            if not out_text:
                if has_att == 1:
                    out_text = "[ATTACHMENT]"
                elif assoc:
                    out_text = "[REACTION/TAPBACK]"
                elif attributed is not None:
                    out_text = "[RICH_TEXT(attributedBody)]"
                else:
                    out_text = "[NON-TEXT MESSAGE]"

            writer.writerow([local_time, sender, out_text, msg_id])
            ftxt.write(f"[{local_time}] {sender}: {out_text}\n")

    # Attachments for this chat
    att_rows = conn.execute(
        """
        SELECT DISTINCT a.ROWID, a.filename
        FROM attachment a
        JOIN message_attachment_join maj ON maj.attachment_id = a.ROWID
        JOIN message m ON m.ROWID = maj.message_id
        JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
        WHERE cmj.chat_id = ?
          AND a.filename IS NOT NULL
        """,
        (chat_id,),
    ).fetchall()

    att_index = chat_dir / "attachments" / "attachments.tsv"
    skipped = chat_dir / "attachments" / "skipped.tsv"

    copied = missing = filtered = 0

    with att_index.open("w", encoding="utf-8") as fa:
        for (arowid, fname) in att_rows:
            fa.write(f"{arowid}\t{fname}\n")

    with skipped.open("w", encoding="utf-8") as fs:
        for (arowid, fname) in att_rows:
            if not fname:
                continue
            src = fname
            if src.startswith("~/"):
                src = str(Path.home() / src[2:])
            src_path = Path(src)

            if not src_path.exists():
                fs.write(f"{arowid}\t{fname}\tMISSING\n")
                missing += 1
                continue

            if not is_useful_attachment(src_path):
                fs.write(f"{arowid}\t{fname}\tFILTERED\n")
                filtered += 1
                continue

            dest = chat_dir / "attachments" / f"{arowid}_{src_path.name}"
            try:
                shutil.copy2(src_path, dest)
                copied += 1
            except Exception:
                fs.write(f"{arowid}\t{fname}\tCOPY_FAILED\n")

    print(f"  Chat {chat_id}: wrote {csv_path.name}, {txt_path.name}; attachments copied={copied}, filtered={filtered}, missing={missing}")


def export_per_chat_for_handle(conn: sqlite3.Connection, out_dir: Path, handle: str, foundation) -> None:
    safe_handle = sanitize_name(handle)
    base_dir = out_dir / safe_handle
    base_dir.mkdir(parents=True, exist_ok=True)

    chats = conn.execute(
        """
        SELECT DISTINCT c.ROWID, COALESCE(c.display_name,'')
        FROM chat c
        JOIN chat_handle_join chj ON chj.chat_id = c.ROWID
        JOIN handle h ON h.ROWID = chj.handle_id
        WHERE h.id = ?
        ORDER BY c.ROWID
        """,
        (handle,),
    ).fetchall()

    if not chats:
        print(f"== Exporting: {handle} ==\n  No chats found.\n")
        return

    print(f"== Exporting: {handle} ==\n  Chats found: {len(chats)}")

    for chat_id, display_name in chats:
        export_single_chat(conn, base_dir, int(chat_id), display_name or "", foundation)

    print("")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", required=True, help="Output directory")
    ap.add_argument(
        "-d",
        "--db",
        default=str(Path.home() / "Library/Messages/chat.db"),
        help="Path to chat.db (default: ~/Library/Messages/chat.db)",
    )
    ap.add_argument("handles", nargs="+", help="Handles (phone numbers or emails) to export")
    args = ap.parse_args()

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    src_db = Path(args.db).expanduser().resolve()
    if not src_db.exists():
        print(f"ERROR: chat.db not found at {src_db}", file=sys.stderr)
        return 2

    tmp_db = copy_db_with_wal(src_db)

    foundation = try_import_foundation()
    if foundation is None:
        print("ERROR: Could not import Foundation via PyObjC.", file=sys.stderr)
        print("Make sure you're on macOS and uv installed dependency 'pyobjc'.", file=sys.stderr)
        return 3

    conn = sqlite3.connect(f"file:{tmp_db}?mode=ro", uri=True)
    try:
        for h in args.handles:
            export_per_chat_for_handle(conn, out_dir, h, foundation)
    finally:
        conn.close()
        try:
            shutil.rmtree(tmp_db.parent)
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
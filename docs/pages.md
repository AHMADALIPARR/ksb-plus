# Page format (Layer 4)

A page is the fixed-size unit of storage: exactly 4096 bytes,
holding a sequence of Layer 3 frames (records). All integers are
big-endian, as in Layers 0-3. A page is always 4096 bytes, in
memory and on disk, so a store is a sequence of pages and page i
lives at file offset i*4096 (Layer 5).

## Layout

| Bytes | Field |
|---|---|
| 0..2 | Magic 75 80 71 ("KPG") |
| 3 | Version 1 (only version accepted) |
| 4..7 | u32be page id (0..4294967295) |
| 8..11 | u32be record count |
| 12..15 | u32be used bytes (header + records, 20..4096) |
| 16..19 | u32be checksum (bCksum over bytes 0..15 plus the record bytes; the checksum field itself is not covered) |
| 20..used-1 | Record bytes (concatenated Layer 0 frames) |
| used..4095 | Zero padding |

Records are self-delimiting Layer 0 frames, so a page is read by
scanning frames from offset 20 until the used bytes are consumed.
No slot directory is needed. The header count must match the
scanned frame count, and the padding must be all zeros.

## Validation order (pParse)

Checks run in this order, and the first failure wins:

1. Type: the page must be an int list.
2. Length: exactly 4096 bytes.
3. Byte range: every byte 0..255.
4. Magic: bytes 0..2 must be 75 80 71, else "magic".
5. Version: byte 3 must be 1, else "version".
6. Used range: 20..4096, else "length".
7. Trailing zeros: bytes used..4095 must sum to 0, else
   "trailing". (Safe because step 3 already proved all bytes
   are non-negative.)
8. Checksum: stored checksum must equal bCksum over bytes 0..15
   plus the record bytes, else "checksum".
9. Frame scan: records must parse as consecutive valid Layer 0
   frames consuming exactly the record bytes, else the frame's
   Layer 0 reason (short, magic, version, length, checksum) or
   "trunc" for leftover bytes.
10. Count match: scanned frame count must equal the header
    count, else "count".

The order matters for corruption tests: shrinking `used` by one
byte usually reports "trailing", not "trunc", because the cut
frame byte is nonzero and lands in the padding region, and the
padding check runs before the scan. Growing `used` by one byte
reports "trunc", because the extra record byte is a zero padding
byte that cannot start a frame.

## API (src/l04.k)

- `pBuild[id;frames]` — build a page from a page id and a list
  of frames. Rejects bad ids ("range"/"type"), non-frame
  elements (the frame's Layer 0 reason), and record totals over
  4076 bytes ("limit").
- `pEmpty[id]` — a header-only page (count 0, used 20).
- `pParse[page]` — full validation; success is
  (1;(id;count;used;frames)).
- `pValid[page]` — full validation as 0/1.
- `pId`, `pCnt`, `pUsed`, `pFree`, `pRead`, `pGet[page;i]` —
  field accessors; each validates the whole page first, so a
  corrupt page never yields a lying field.
- `pAppend[page;frame]` — rebuild the page with one more frame
  (same id, count + 1). A failed append leaves the input page
  untouched; the caller keeps the old page on (0;reason). The
  limit check compares the NEW USED total against 4096, not
  against 4076: 4076 is the record-bytes maximum, 4096 is the
  page size, and used already includes the 20-byte header.

## Limitations (stated, not hidden)

- Pages are byte lists in Kona memory. There is no mmap or
  direct-disk page I/O in this layer; persistence is Layer 5's
  job, on top of Kona's file verbs.
- The Adler-style checksum is an integrity check only, never
  proof of authenticity.
- Frame assembly uses concat, as in Layer 3, so building pages
  with very many records copies repeatedly. Pages hold at most
  4076 record bytes, so this is bounded by the page size.

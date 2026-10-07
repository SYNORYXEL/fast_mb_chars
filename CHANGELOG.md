# Changelog

## 0.1.0

`String#mb_chars` with the usual case, split, and Unicode helpers, plus `limit(bytes)`.

The gem prepends `String#mb_chars`. ASCII and UTF-8 are supported. Other encodings need `encode('UTF-8')` first.

The byte cut stays on a character boundary. A character that crosses the limit is kept when it finishes within 128 bytes. A longer combining sequence is dropped. Invalid bytes do not raise.

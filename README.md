# jlog

A small, fast, read-only pager for JSON Lines logs (JSONL / NDJSON), shipped as one
native executable per platform.

`jlog` opens a file, a pipe, or a file picker and shows each log record as a table row.
It recognizes time, level and message fields automatically, so zerolog, zap, logrus,
slog, pino and similar output looks right without configuration. It never modifies its
input.

# show

Pager / file viewer written in x86_64 Linux assembly. Reads files via
`mmap`, renders syntax-highlighted output. No libc, no dynamic
linking. ~3.5k lines of NASM, ~40KB static binary.

## Build

```bash
nasm -f elf64 show.asm -o show.o && ld show.o -o show
```

## Modes

- **Cat mode** (default, output piped or file < terminal height):
  emits the whole file with highlighting + ESC sanitisation, exits.
- **Pane mode** (`--lines M-N`): outputs a specific line range, no
  raw-mode key handling. Used by [pointer](https://github.com/isene/pointer)
  and [RTFM](https://github.com/isene/RTFM) for embedded preview.
- **Pager mode** (interactive TTY, file > height): raw mode + key
  handlers (j/k/g/G/space/b/q, /search, n/N).

## Architecture

### File loading via mmap

```nasm
; Open
mov rax, SYS_OPEN
lea rdi, [file_path]
xor esi, esi                        ; O_RDONLY
syscall

; Size via fstat (144-byte struct)
mov rax, SYS_FSTAT
mov rdi, fd
lea rsi, [stat_buf]
syscall
mov r12, [stat_buf + 48]            ; st_size

; Mmap read-only
mov rax, SYS_MMAP
xor edi, edi                        ; addr = NULL
mov rsi, r12                        ; length
mov rdx, PROT_READ                  ; 1
mov r10, MAP_PRIVATE                ; 2
mov r8, fd
xor r9d, r9d                        ; offset = 0
syscall
```

The whole file becomes a contiguous read-only buffer. Line offsets
are computed once at startup by scanning for `\n` and stored as a
sorted array — random-access jumping by line is then O(1).

### Syntax highlighting

- Language detected from file extension or shebang (`#!/usr/bin/env ruby`)
- Keyword/type tables: NUL-separated strings, double-NUL terminated
- Dispatch tables: arrays of qword pointers indexed by language ID
- State machine per line: `ST_NORMAL`, `ST_STRING_DQ`, `ST_STRING_SQ`,
  `ST_COMMENT_LINE`, `ST_COMMENT_BLOCK`
- Block comment state persists across lines via `hl_state`
- Themes: 8-byte arrays (keyword, string, comment, number, type, func,
  preproc, punct); colours stored in BSS at startup

### ESC sanitisation

Untrusted input might contain raw ESC sequences. Cat mode replaces
ESC bytes with `^[` literal so a malicious file can't reposition the
cursor / change colours / set window title. Pager mode re-renders
fully so the source ESCs never reach the terminal.

## Key code sections

- `_start`: arg parse, file open + mmap, mode detection
- `mode_cat`: emit highlighted output + exit
- `mode_pane`: line-range output (no raw mode)
- `mode_pager`: raw-mode entry, key loop
- `highlight_line`: per-line state machine + dispatch
- `lang_detect`: extension/shebang dispatch
- `find_line_starts`: one-pass scan, fills `line_offsets[]`

## Pitfalls

See the global x86_64-asm skill for the 15 NASM/x86_64 pitfalls that
apply across every CHasm project. show-specific points:

- **`fstat` on a pipe returns size 0** — pager mode needs a real
  file; pipes get cat mode.
- **mmap fails on empty files** — fall back to "no content" branch
  before calling mmap with size=0 (which mmap rejects).
- **The file mapping is read-only** — never try to write into it; for
  search results, use a separate writable buffer.
- **Raw mode setup MUST be paired with a SIGINT handler that restores
  cooked mode** — otherwise Ctrl-C in pager mode leaves the user's
  shell with broken termios.

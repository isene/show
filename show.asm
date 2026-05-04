; show - Pure assembly file viewer with syntax highlighting
; Part of CHasm (CHange to ASM)
; x86_64 Linux, NASM syntax, no libc, pure syscalls

; ══════════════════════════════════════════════════════════════════════
; Syscall numbers
; ══════════════════════════════════════════════════════════════════════
%define SYS_READ        0
%define SYS_WRITE       1
%define SYS_OPEN        2
%define SYS_CLOSE       3
%define SYS_FSTAT       5
%define SYS_MMAP        9
%define SYS_MUNMAP      11
%define SYS_IOCTL       16
%define SYS_EXIT        60
%define SYS_RT_SIGACTION 13
%define SYS_CLOCK_GETTIME 228

; ══════════════════════════════════════════════════════════════════════
; Constants
; ══════════════════════════════════════════════════════════════════════
%define O_RDONLY        0
%define PROT_READ       1
%define MAP_PRIVATE     2
%define TCGETS          0x5401
%define TCSETSW         0x5403
%define TIOCGWINSZ      0x5413
%define ICANON          0x2
%define ECHO            0x8
%define ISIG            0x1
%define VMIN            6
%define VTIME           5
%define SIGINT          2
%define SIGWINCH        28
%define SIG_IGN         1
%define CLOCK_MONOTONIC 1

; Limits
%define MAX_LINES       262144
%define MAX_PIPE_BUF    1048576
%define MAX_SEARCH_LEN  256
%define TAB_WIDTH       8
%define OUT_BUF_SIZE    65536

; Mode constants
%define MODE_CAT        0
%define MODE_PAGER      1
%define MODE_PIPE       2
%define MODE_PANE       3

; Language IDs
%define LANG_NONE       0
%define LANG_RUBY       1
%define LANG_PYTHON     2
%define LANG_RUST       3
%define LANG_ASM        4
%define LANG_SHELL      5
%define LANG_JS         6
%define LANG_C          7
%define LANG_GO         8
%define LANG_MD         9
%define LANG_JSON       10
%define LANG_YAML       11
%define LANG_TOML       12
%define LANG_CONF       13
%define LANG_LUA        14
%define LANG_JAVA       15
%define LANG_CSHARP     16
%define LANG_FORTH      17
%define LANG_XRPN       18
%define LANG_JULIA      19

; Highlight state
%define ST_NORMAL       0
%define ST_STRING_DQ    1
%define ST_STRING_SQ    2
%define ST_COMMENT_LINE 3
%define ST_COMMENT_BLOCK 4

; Colors (256-color)
%define COL_KEYWORD     197
%define COL_STRING      78
%define COL_COMMENT     242
%define COL_NUMBER      141
%define COL_TYPE        81
%define COL_FUNC        148
%define COL_NORMAL      252
%define COL_LINENO      240
%define COL_STATUS_BG   236
%define COL_HEADING     81
%define COL_OPERATOR    248
%define COL_PREPROC     139

; Key codes (internal)
%define KEY_UP          1001
%define KEY_DOWN        1002
%define KEY_RIGHT       1003
%define KEY_LEFT        1004
%define KEY_PGUP        1005
%define KEY_PGDN        1006
%define KEY_HOME        1007
%define KEY_END         1008

; ══════════════════════════════════════════════════════════════════════
; Data section
; ══════════════════════════════════════════════════════════════════════
section .data

newline:        db 10
reset_seq:      db 27, "[0m"
reset_seq_len   equ $ - reset_seq
bold_seq:       db 27, "[1m"
bold_seq_len    equ $ - bold_seq
reverse_seq:    db 27, "[7m"
reverse_seq_len equ $ - reverse_seq
clr_eol:        db 27, "[K"
clr_eol_len     equ $ - clr_eol
clr_screen:     db 27, "[2J"
clr_screen_len  equ $ - clr_screen
cursor_home:    db 27, "[H"
cursor_home_len equ $ - cursor_home
hide_cursor:    db 27, "[?25l"
hide_cursor_len equ $ - hide_cursor
show_cursor:    db 27, "[?25h"
show_cursor_len equ $ - show_cursor
alt_screen_on:  db 27, "[?1049h"
alt_screen_on_len equ $ - alt_screen_on
alt_screen_off: db 27, "[?1049l"
alt_screen_off_len equ $ - alt_screen_off

err_usage:      db "Usage: show [--lines M-N] [--width W] [file]", 10
err_usage_len   equ $ - err_usage
err_open:       db "show: cannot open file: "
err_open_len    equ $ - err_open
err_mmap:       db "show: mmap failed", 10
err_mmap_len    equ $ - err_mmap

version_str:    db "show 0.1.3", 10
version_str_len equ $ - version_str

; Separator for line numbers
lineno_sep:     db 27, "[38;5;240m", " | ", 27, "[0m"
lineno_sep_len  equ $ - lineno_sep

; Extension to language mapping
ext_table:
    dq .e_rb,   LANG_RUBY
    dq .e_py,   LANG_PYTHON
    dq .e_rs,   LANG_RUST
    dq .e_asm,  LANG_ASM
    dq .e_s,    LANG_ASM
    dq .e_sh,   LANG_SHELL
    dq .e_bash, LANG_SHELL
    dq .e_zsh,  LANG_SHELL
    dq .e_fish, LANG_SHELL
    dq .e_js,   LANG_JS
    dq .e_ts,   LANG_JS
    dq .e_c,    LANG_C
    dq .e_h,    LANG_C
    dq .e_cpp,  LANG_C
    dq .e_go,   LANG_GO
    dq .e_md,   LANG_MD
    dq .e_json, LANG_JSON
    dq .e_yaml, LANG_YAML
    dq .e_yml,  LANG_YAML
    dq .e_toml, LANG_TOML
    dq .e_conf, LANG_CONF
    dq .e_cfg,  LANG_CONF
    dq .e_ini,  LANG_CONF
    dq .e_lua,  LANG_LUA
    dq .e_java, LANG_JAVA
    dq .e_cs,   LANG_CSHARP
    dq .e_fth,  LANG_FORTH
    dq .e_4th,  LANG_FORTH
    dq .e_forth,LANG_FORTH
    dq .e_xrpn, LANG_XRPN
    dq .e_jl,   LANG_JULIA
    dq 0, 0
.e_rb:   db ".rb", 0
.e_py:   db ".py", 0
.e_rs:   db ".rs", 0
.e_asm:  db ".asm", 0
.e_s:    db ".s", 0
.e_sh:   db ".sh", 0
.e_bash: db ".bash", 0
.e_zsh:  db ".zsh", 0
.e_fish: db ".fish", 0
.e_js:   db ".js", 0
.e_ts:   db ".ts", 0
.e_c:    db ".c", 0
.e_h:    db ".h", 0
.e_cpp:  db ".cpp", 0
.e_go:   db ".go", 0
.e_md:   db ".md", 0
.e_json: db ".json", 0
.e_yaml: db ".yaml", 0
.e_yml:  db ".yml", 0
.e_toml: db ".toml", 0
.e_conf: db ".conf", 0
.e_cfg:  db ".cfg", 0
.e_ini:  db ".ini", 0
.e_lua:  db ".lua", 0
.e_java: db ".java", 0
.e_cs:   db ".cs", 0
.e_fth:  db ".fth", 0
.e_4th:  db ".4th", 0
.e_forth: db ".forth", 0
.e_xrpn: db ".xrpn", 0
.e_jl:   db ".jl", 0

; Comment style table: indexed by LANG_* (line_comment, block_open, block_close)
comment_table:
    dq 0, 0, 0                          ; LANG_NONE
    dq cmt_hash, 0, 0                   ; LANG_RUBY
    dq cmt_hash, 0, 0                   ; LANG_PYTHON
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_RUST
    dq cmt_semi, 0, 0                   ; LANG_ASM
    dq cmt_hash, 0, 0                   ; LANG_SHELL
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_JS
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_C
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_GO
    dq 0, 0, 0                          ; LANG_MD
    dq 0, 0, 0                          ; LANG_JSON
    dq cmt_hash, 0, 0                   ; LANG_YAML
    dq cmt_hash, 0, 0                   ; LANG_TOML
    dq cmt_hash, 0, 0                   ; LANG_CONF
    dq cmt_dash2, cmt_dashbrak, cmt_brakdash ; LANG_LUA
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_JAVA
    dq cmt_slash2, cmt_slashstar, cmt_starslash ; LANG_CSHARP
    dq cmt_backslash, cmt_paren, cmt_closeparen ; LANG_FORTH
    dq cmt_semi, 0, 0                   ; LANG_XRPN
    dq cmt_hash, 0, 0                   ; LANG_JULIA
; Shebang to language mapping
shebang_table:
    dq .sb_ruby,   LANG_RUBY
    dq .sb_python,  LANG_PYTHON
    dq .sb_python3, LANG_PYTHON
    dq .sb_bash,   LANG_SHELL
    dq .sb_sh,     LANG_SHELL
    dq .sb_zsh,    LANG_SHELL
    dq .sb_fish,   LANG_SHELL
    dq .sb_node,   LANG_JS
    dq .sb_perl,   LANG_SHELL
    dq .sb_lua,    LANG_LUA
    dq .sb_julia,  LANG_JULIA
    dq 0, 0
.sb_ruby:    db "ruby", 0
.sb_python:  db "python", 0
.sb_python3: db "python3", 0
.sb_bash:    db "bash", 0
.sb_sh:      db "sh", 0
.sb_zsh:     db "zsh", 0
.sb_fish:    db "fish", 0
.sb_node:    db "node", 0
.sb_perl:    db "perl", 0
.sb_lua:     db "lua", 0
.sb_julia:   db "julia", 0

cmt_hash:      db "#", 0
cmt_slash2:    db "//", 0
cmt_semi:      db ";", 0
cmt_dash2:     db "--", 0
cmt_slashstar: db "/*", 0
cmt_starslash: db "*/", 0
cmt_dashbrak:  db "--[[", 0
cmt_brakdash:  db "]]", 0
cmt_backslash: db "\ ", 0
cmt_paren:     db "( ", 0
cmt_closeparen: db " )", 0

; Keyword tables (null-separated, double-null terminated)
kw_ruby:
    db "def",0,"end",0,"class",0,"module",0,"if",0,"elsif",0,"else",0
    db "unless",0,"while",0,"until",0,"do",0,"return",0,"yield",0
    db "begin",0,"rescue",0,"ensure",0,"require",0,"include",0
    db "nil",0,"true",0,"false",0,"self",0,"then",0,"and",0,"or",0,"not",0
    db "case",0,"when",0,"for",0,"in",0,"break",0,"next",0,"raise",0, 0

kw_python:
    db "def",0,"class",0,"if",0,"elif",0,"else",0,"while",0,"for",0
    db "return",0,"import",0,"from",0,"as",0,"with",0,"try",0,"except",0
    db "finally",0,"raise",0,"pass",0,"break",0,"continue",0,"yield",0
    db "None",0,"True",0,"False",0,"and",0,"or",0,"not",0,"in",0
    db "is",0,"lambda",0,"global",0,"nonlocal",0,"assert",0,"del",0
    db "async",0,"await",0, 0

kw_rust:
    db "fn",0,"let",0,"mut",0,"if",0,"else",0,"while",0,"for",0,"loop",0
    db "match",0,"return",0,"struct",0,"enum",0,"impl",0,"trait",0
    db "pub",0,"use",0,"mod",0,"crate",0,"self",0,"super",0,"where",0
    db "type",0,"const",0,"static",0,"ref",0,"move",0,"async",0,"await",0
    db "true",0,"false",0,"Some",0,"None",0,"Ok",0,"Err",0,"Self",0
    db "break",0,"continue",0,"unsafe",0,"extern",0,"as",0,"in",0, 0

kw_c:
    db "if",0,"else",0,"while",0,"for",0,"do",0,"switch",0,"case",0
    db "break",0,"continue",0,"return",0,"struct",0,"enum",0,"union",0
    db "typedef",0,"const",0,"static",0,"extern",0,"void",0,"int",0
    db "char",0,"long",0,"short",0,"unsigned",0,"signed",0,"float",0
    db "double",0,"sizeof",0,"NULL",0,"true",0,"false",0
    db "include",0,"define",0,"ifdef",0,"endif",0,"ifndef",0, 0

kw_go:
    db "func",0,"package",0,"import",0,"if",0,"else",0,"for",0,"range",0
    db "return",0,"var",0,"const",0,"type",0,"struct",0,"interface",0
    db "map",0,"chan",0,"go",0,"defer",0,"select",0,"case",0,"switch",0
    db "break",0,"continue",0,"fallthrough",0,"default",0
    db "nil",0,"true",0,"false",0,"make",0,"new",0,"append",0,"len",0, 0

kw_shell:
    db "if",0,"then",0,"else",0,"elif",0,"fi",0,"for",0,"while",0,"do",0
    db "done",0,"case",0,"esac",0,"function",0,"return",0,"exit",0
    db "echo",0,"export",0,"local",0,"readonly",0,"shift",0,"source",0
    db "true",0,"false",0,"in",0,"set",0,"unset",0, 0

kw_js:
    db "function",0,"var",0,"let",0,"const",0,"if",0,"else",0,"for",0
    db "while",0,"do",0,"switch",0,"case",0,"break",0,"continue",0
    db "return",0,"class",0,"extends",0,"new",0,"this",0,"super",0
    db "import",0,"export",0,"from",0,"default",0,"async",0,"await",0
    db "try",0,"catch",0,"finally",0,"throw",0,"typeof",0,"instanceof",0
    db "null",0,"undefined",0,"true",0,"false",0,"of",0,"in",0, 0

kw_asm:
    db "mov",0,"push",0,"pop",0,"call",0,"ret",0,"jmp",0,"je",0,"jne",0
    db "jz",0,"jnz",0,"jg",0,"jge",0,"jl",0,"jle",0,"js",0,"jns",0
    db "cmp",0,"test",0,"add",0,"sub",0,"inc",0,"dec",0,"mul",0,"div",0
    db "xor",0,"and",0,"or",0,"not",0,"shl",0,"shr",0,"lea",0,"nop",0
    db "syscall",0,"int",0,"rep",0,"movzx",0,"movsx",0,"imul",0,"idiv",0
    db "section",0,"global",0,"extern",0,"db",0,"dw",0,"dd",0,"dq",0
    db "resb",0,"resw",0,"resd",0,"resq",0,"equ",0, 0

kw_lua:
    db "and",0,"break",0,"do",0,"else",0,"elseif",0,"end",0,"false",0
    db "for",0,"function",0,"goto",0,"if",0,"in",0,"local",0,"nil",0
    db "not",0,"or",0,"repeat",0,"return",0,"then",0,"true",0,"until",0
    db "while",0, 0

kw_java:
    db "abstract",0,"assert",0,"boolean",0,"break",0,"byte",0,"case",0
    db "catch",0,"char",0,"class",0,"const",0,"continue",0,"default",0
    db "do",0,"double",0,"else",0,"enum",0,"extends",0,"final",0
    db "finally",0,"float",0,"for",0,"if",0,"implements",0,"import",0
    db "instanceof",0,"int",0,"interface",0,"long",0,"native",0,"new",0
    db "null",0,"package",0,"private",0,"protected",0,"public",0
    db "return",0,"short",0,"static",0,"super",0,"switch",0
    db "synchronized",0,"this",0,"throw",0,"throws",0,"transient",0
    db "try",0,"void",0,"volatile",0,"while",0,"true",0,"false",0, 0

kw_csharp:
    db "abstract",0,"as",0,"base",0,"bool",0,"break",0,"byte",0,"case",0
    db "catch",0,"char",0,"class",0,"const",0,"continue",0,"decimal",0
    db "default",0,"delegate",0,"do",0,"double",0,"else",0,"enum",0
    db "event",0,"explicit",0,"extern",0,"false",0,"finally",0,"fixed",0
    db "float",0,"for",0,"foreach",0,"goto",0,"if",0,"implicit",0
    db "in",0,"int",0,"interface",0,"internal",0,"is",0,"lock",0,"long",0
    db "namespace",0,"new",0,"null",0,"object",0,"operator",0,"out",0
    db "override",0,"params",0,"private",0,"protected",0,"public",0
    db "readonly",0,"ref",0,"return",0,"sealed",0,"short",0,"sizeof",0
    db "static",0,"string",0,"struct",0,"switch",0,"this",0,"throw",0
    db "true",0,"try",0,"typeof",0,"uint",0,"ulong",0,"unchecked",0
    db "unsafe",0,"ushort",0,"using",0,"var",0,"virtual",0,"void",0
    db "volatile",0,"while",0,"yield",0,"async",0,"await",0, 0

kw_forth:
    db "DUP",0,"DROP",0,"SWAP",0,"OVER",0,"ROT",0,"NIP",0,"TUCK",0
    db "IF",0,"ELSE",0,"THEN",0,"DO",0,"LOOP",0,"BEGIN",0,"UNTIL",0
    db "WHILE",0,"REPEAT",0,"VARIABLE",0,"CONSTANT",0,"CREATE",0
    db "DOES>",0,"ALLOT",0,"CELLS",0,"HERE",0,"EMIT",0,"KEY",0,"TYPE",0
    db "ACCEPT",0,"CR",0,"SPACE",0,"SPACES",0,"EXECUTE",0,"EXIT",0
    db "RECURSE",0,"POSTPONE",0,"IMMEDIATE",0,"LITERAL",0
    db "dup",0,"drop",0,"swap",0,"over",0,"rot",0,"nip",0,"tuck",0
    db "if",0,"else",0,"then",0,"do",0,"loop",0,"begin",0,"until",0
    db "while",0,"repeat",0,"variable",0,"constant",0,"create",0
    db "emit",0,"key",0,"type",0,"accept",0,"cr",0,"space",0,"execute",0
    db "exit",0,"recurse",0,"postpone",0,"immediate",0,"literal",0, 0

kw_xrpn:
    db "LBL",0,"GTO",0,"XEQ",0,"STO",0,"RCL",0,"RTN",0,"END",0
    db "ENTER",0,"STOP",0,"CLA",0,"CLX",0,"CLRG",0,"LASTX",0
    db "SWAP",0,"RUP",0,"RDN",0,"AVIEW",0,"VIEW",0,"PROMPT",0
    db "FS?",0,"FC?",0,"SF",0,"CF",0,"ISG",0,"DSE",0, 0

kw_julia:
    db "function",0,"end",0,"if",0,"else",0,"elseif",0,"while",0,"for",0
    db "return",0,"module",0,"struct",0,"mutable",0,"abstract",0
    db "primitive",0,"type",0,"begin",0,"let",0,"do",0,"try",0,"catch",0
    db "finally",0,"throw",0,"import",0,"using",0,"export",0,"macro",0
    db "quote",0,"local",0,"global",0,"const",0,"break",0,"continue",0
    db "true",0,"false",0,"nothing",0,"in",0,"isa",0,"where",0, 0

; Keyword dispatch table (indexed by LANG_*)
kw_dispatch:
    dq 0            ; LANG_NONE
    dq kw_ruby      ; LANG_RUBY
    dq kw_python    ; LANG_PYTHON
    dq kw_rust      ; LANG_RUST
    dq kw_asm       ; LANG_ASM
    dq kw_shell     ; LANG_SHELL
    dq kw_js        ; LANG_JS
    dq kw_c         ; LANG_C
    dq kw_go        ; LANG_GO
    dq 0            ; LANG_MD
    dq 0            ; LANG_JSON
    dq 0            ; LANG_YAML
    dq 0            ; LANG_TOML
    dq 0            ; LANG_CONF
    dq kw_lua       ; LANG_LUA
    dq kw_java      ; LANG_JAVA
    dq kw_csharp    ; LANG_CSHARP
    dq kw_forth     ; LANG_FORTH
    dq kw_xrpn      ; LANG_XRPN
    dq kw_julia     ; LANG_JULIA

; Type tables (null-separated, double-null terminated)
tp_ruby:
    db "String",0,"Integer",0,"Float",0,"Array",0,"Hash",0,"Symbol",0
    db "Proc",0,"IO",0,"File",0,"Dir",0,"Regexp",0,"Range",0
    db "Struct",0,"Class",0,"Module",0,"Kernel",0,"Object",0
    db "NilClass",0,"TrueClass",0,"FalseClass",0,"Numeric",0, 0

tp_python:
    db "int",0,"float",0,"str",0,"bool",0,"list",0,"dict",0
    db "tuple",0,"set",0,"bytes",0,"type",0,"object",0,"Exception",0, 0

tp_rust:
    db "i8",0,"i16",0,"i32",0,"i64",0,"i128",0
    db "u8",0,"u16",0,"u32",0,"u64",0,"u128",0
    db "f32",0,"f64",0,"bool",0,"char",0,"str",0
    db "String",0,"Vec",0,"Option",0,"Result",0,"Box",0
    db "Rc",0,"Arc",0,"HashMap",0,"HashSet",0,"usize",0,"isize",0, 0

tp_c:
    db "int",0,"char",0,"float",0,"double",0,"void",0
    db "long",0,"short",0,"unsigned",0,"signed",0,"bool",0
    db "size_t",0,"string",0,"vector",0,"map",0,"set",0,"auto",0, 0

tp_go:
    db "int",0,"int8",0,"int16",0,"int32",0,"int64",0
    db "uint",0,"uint8",0,"uint16",0,"uint32",0,"uint64",0
    db "float32",0,"float64",0,"string",0,"bool",0
    db "byte",0,"rune",0,"error",0,"nil",0,"iota",0, 0

tp_js:
    db "string",0,"number",0,"boolean",0,"any",0,"void",0
    db "null",0,"undefined",0,"never",0,"object",0
    db "Array",0,"Promise",0,"Map",0,"Set",0,"Record",0,"Partial",0, 0

tp_java:
    db "int",0,"long",0,"float",0,"double",0,"boolean",0
    db "char",0,"byte",0,"short",0,"String",0,"Integer",0
    db "Long",0,"Float",0,"Double",0,"Object",0,"List",0,"Map",0,"Set",0, 0

tp_lua:
    db "string",0,"number",0,"table",0,"boolean",0,"thread",0,"userdata",0, 0

tp_asm:
    db "rax",0,"rbx",0,"rcx",0,"rdx",0,"rsi",0,"rdi",0,"rsp",0,"rbp",0
    db "r8",0,"r9",0,"r10",0,"r11",0,"r12",0,"r13",0,"r14",0,"r15",0
    db "eax",0,"ebx",0,"ecx",0,"edx",0,"esi",0,"edi",0,"esp",0,"ebp",0
    db "al",0,"bl",0,"cl",0,"dl",0,"ah",0,"bh",0,"ch",0,"dh",0, 0

tp_csharp:
    db "int",0,"long",0,"float",0,"double",0,"bool",0,"char",0
    db "string",0,"object",0,"void",0,"byte",0,"decimal",0
    db "var",0,"List",0,"Dictionary",0, 0

tp_julia:
    db "Int",0,"Int8",0,"Int16",0,"Int32",0,"Int64",0
    db "Float16",0,"Float32",0,"Float64",0,"Bool",0,"Char",0
    db "String",0,"Vector",0,"Array",0,"Dict",0,"Nothing",0, 0

; Type dispatch table (indexed by LANG_*)
tp_dispatch:
    dq 0            ; LANG_NONE
    dq tp_ruby      ; LANG_RUBY
    dq tp_python    ; LANG_PYTHON
    dq tp_rust      ; LANG_RUST
    dq tp_asm       ; LANG_ASM
    dq 0            ; LANG_SHELL
    dq tp_js        ; LANG_JS
    dq tp_c         ; LANG_C
    dq tp_go        ; LANG_GO
    dq 0            ; LANG_MD
    dq 0            ; LANG_JSON
    dq 0            ; LANG_YAML
    dq 0            ; LANG_TOML
    dq 0            ; LANG_CONF
    dq tp_lua       ; LANG_LUA
    dq tp_java      ; LANG_JAVA
    dq tp_csharp    ; LANG_CSHARP
    dq 0            ; LANG_FORTH
    dq 0            ; LANG_XRPN
    dq tp_julia     ; LANG_JULIA

; Theme data: keyword, string, comment, number, type, func, preproc, punct
; 8 bytes per theme
theme_names:
    dq .tn_monokai, .tn_solarized, .tn_nord, .tn_dracula, .tn_gruvbox, .tn_plain
    dq 0
.tn_monokai:   db "monokai", 0
.tn_solarized: db "solarized", 0
.tn_nord:      db "nord", 0
.tn_dracula:   db "dracula", 0
.tn_gruvbox:   db "gruvbox", 0
.tn_plain:     db "plain", 0

theme_data:
;                kw   str  cmt  num  typ  func prep punct
.td_monokai:   db 197, 78,  242, 141, 81,  148, 197, 248
.td_solarized: db 136, 64,  245, 125, 33,  166, 136, 240
.td_nord:      db 110, 108, 60,  176, 73,  222, 110, 103
.td_dracula:   db 212, 84,  61,  141, 117, 228, 212, 189
.td_gruvbox:   db 167, 142, 245, 175, 109, 214, 167, 223
.td_plain:     db 252, 252, 245, 252, 252, 252, 252, 245

flag_theme: db "--theme", 0
flag_raw:   db "--raw", 0

; Operator characters (null-terminated)
op_chars: db "=+-*/<>!&|^~%", 0

; Double operators (2-char, null-terminated pairs list, double-null end)
op_doubles:
    db "==",0,"!=",0,"<=",0,">=",0,"&&",0,"||",0,"::",0
    db "+=",0,"-=",0,"*=",0,"/=",0,"<<",0,">>",0,"->",0, 0

; ══════════════════════════════════════════════════════════════════════
; BSS section
; ══════════════════════════════════════════════════════════════════════
section .bss

; Mode and state
mode:               resq 1
is_tty:             resq 1
stdout_is_tty:      resq 1

; Terminal
orig_termios:       resb 60
raw_termios:        resb 60
term_rows:          resq 1
term_cols:          resq 1
winch_flag:         resq 1

; File data
file_buf:           resq 1          ; mmap'd address or pipe_buf
file_size:          resq 1
file_path:          resb 4096

; Pipe input
pipe_buf:           resb MAX_PIPE_BUF
pipe_len:           resq 1

; Line index
line_offsets:       resq MAX_LINES
line_count:         resq 1

; Viewport
top_line:           resq 1
left_col:           resq 1
show_line_numbers:  resq 1
lineno_width:       resq 1

; Pane mode params
pane_start_line:    resq 1
pane_end_line:      resq 1
pane_width:         resq 1

; Active theme colors
th_keyword:         resb 1
th_string:          resb 1
th_comment:         resb 1
th_number:          resb 1
th_type:            resb 1
th_func:            resb 1
th_preproc:         resb 1
th_punct:           resb 1

; Syntax highlighting
language:           resq 1
kw_table_ptr:       resq 1
type_table_ptr:     resq 1
comment_line_ptr:   resq 1
comment_blk_open:   resq 1
comment_blk_close:  resq 1
hl_state:           resq 1

; Search
search_buf:         resb MAX_SEARCH_LEN
search_len:         resq 1
search_active:      resq 1

; Output buffer
out_buf:            resb OUT_BUF_SIZE
out_pos:            resq 1
; When out_safe = 1, out_char neutralises bytes that would let a
; malicious file inject terminal escape sequences (ESC and the
; eight-bit C1 controls 0x90/0x9B/0x9D/0x9E/0x9F). Show's own
; ANSI emissions wrap their writes with out_safe = 0 so colour
; codes still pass through verbatim.
out_safe:           resb 1
; tty_out is set at startup if fd 1 is a character device. When 0
; (output is redirected to a file or pipe) sanitization is skipped
; so a captured `show foo.c > foo.ansi` keeps the colour escapes.
; --raw on the command line forces tty_out = 0.
tty_out:            resb 1

; Render scratch
num_buf:            resb 32
tmp_buf:            resb 64
stat_buf:           resb 144

; ══════════════════════════════════════════════════════════════════════
; Text section
; ══════════════════════════════════════════════════════════════════════
section .text
global _start

_start:
    ; Initialize default theme (monokai)
    call init_default_theme

    ; Probe stdout: if it's a character device (terminal) enable
    ; file-byte sanitization so a malicious file viewed via show
    ; can't inject terminal escape sequences into the parent shell.
    ; struct stat is 144 bytes; we only need st_mode at offset 24.
    sub rsp, 144
    mov rax, SYS_FSTAT
    mov rdi, 1                  ; stdout
    mov rsi, rsp
    syscall
    test rax, rax
    js .start_no_tty_probe
    mov eax, [rsp + 24]         ; st_mode
    and eax, 0xF000             ; S_IFMT
    cmp eax, 0x2000             ; S_IFCHR
    jne .start_no_tty_probe
    mov byte [tty_out], 1
.start_no_tty_probe:
    add rsp, 144

    ; Parse arguments
    mov rdi, [rsp]          ; argc
    lea rsi, [rsp + 8]      ; argv
    cmp rdi, 1
    jle .check_stdin

    ; Scan for --raw (overrides tty probe). Must run before --theme
    ; because we want the override applied regardless of arg order.
    push rdi
    push rsi
    mov rcx, 1
.scan_raw:
    cmp rcx, rdi
    jge .scan_raw_done
    mov rax, [rsi + rcx*8]
    test rax, rax
    jz .scan_raw_done
    push rcx
    push rdi
    push rsi
    mov rdi, rax
    lea rsi, [flag_raw]
    call strcmp
    pop rsi
    pop rdi
    pop rcx
    test rax, rax
    jnz .scan_raw_next
    mov byte [tty_out], 0
.scan_raw_next:
    inc rcx
    jmp .scan_raw
.scan_raw_done:
    pop rsi
    pop rdi

    ; Scan all argv for --theme before other processing
    push rdi
    push rsi
    mov rcx, 1
.scan_theme:
    cmp rcx, rdi
    jge .scan_theme_done
    mov rax, [rsi + rcx*8]
    test rax, rax
    jz .scan_theme_done
    ; Check for "--theme"
    push rcx
    push rdi
    push rsi
    mov rdi, rax
    lea rsi, [flag_theme]
    call strcmp
    pop rsi
    pop rdi
    pop rcx
    test rax, rax
    jnz .scan_theme_next
    ; Found --theme, next arg is theme name
    inc rcx
    cmp rcx, rdi
    jge .scan_theme_done
    mov rdi, [rsi + rcx*8]
    call set_theme
    jmp .scan_theme_done
.scan_theme_next:
    inc rcx
    jmp .scan_theme
.scan_theme_done:
    pop rsi
    pop rdi

    ; Check argv[1]
    mov rax, [rsi + 8]      ; argv[1]
    test rax, rax
    jz .check_stdin
    ; Skip --theme and its arg
    push rdi
    push rsi
    mov rdi, rax
    lea rsi, [flag_theme]
    call strcmp
    pop rsi
    pop rdi
    test rax, rax
    jnz .not_theme_arg
    ; argv[1] is --theme, skip to argv[3]
    cmp rdi, 4
    jl .check_stdin
    mov rax, [rsi + 24]     ; argv[3]
    test rax, rax
    jz .check_stdin
    jmp .have_filename_direct
.not_theme_arg:
    ; Skip a leading --raw (already consumed by the scan above).
    ; --raw takes no value so the filename is at argv[2].
    mov rax, [rsi + 8]
    push rdi
    push rsi
    mov rdi, rax
    lea rsi, [flag_raw]
    call strcmp
    pop rsi
    pop rdi
    test rax, rax
    jnz .not_raw_arg
    cmp rdi, 3
    jl .check_stdin
    mov rax, [rsi + 16]
    test rax, rax
    jz .check_stdin
    jmp .have_filename_direct
.not_raw_arg:
    mov rax, [rsi + 8]      ; reload argv[1]

    ; Check for --version
    cmp dword [rax], '--ve'
    jne .check_lines_flag
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [version_str]
    mov rdx, version_str_len
    syscall
    xor edi, edi
    mov rax, SYS_EXIT
    syscall

.check_lines_flag:
    ; Check for --lines M-N
    mov rax, [rsi + 8]
    cmp dword [rax], '--li'
    jne .check_width_flag
    ; Parse --lines
    mov qword [mode], MODE_PANE
    cmp rdi, 3
    jl .usage
    mov rax, [rsi + 16]     ; argv[2] = "M-N"
    call parse_range         ; sets pane_start_line, pane_end_line
    ; Check for --width or filename after
    cmp qword [rsp], 4      ; argc >= 4?
    jl .usage
    mov rax, [rsi + 24]     ; argv[3]
    cmp dword [rax], '--wi'
    jne .pane_filename_3
    ; Parse --width
    cmp qword [rsp], 6      ; argc >= 6?
    jl .usage
    mov rax, [rsi + 32]     ; argv[4] = width
    call parse_int
    mov [pane_width], rax
    mov rax, [rsi + 40]     ; argv[5] = filename
    jmp .have_filename
.pane_filename_3:
    ; argv[3] is filename
    mov rax, [rsi + 24]
    jmp .have_filename

.check_width_flag:
    mov rax, [rsi + 8]
    cmp dword [rax], '--wi'
    jne .regular_file
    mov qword [mode], MODE_PANE
    cmp rdi, 4
    jl .usage
    mov rax, [rsi + 16]
    call parse_int
    mov [pane_width], rax
    mov rax, [rsi + 24]
    jmp .have_filename

.regular_file:
    mov rax, [rsi + 8]      ; argv[1] = filename
.have_filename_direct:
.have_filename:
    ; Copy filename to file_path
    mov rsi, rax
    lea rdi, [file_path]
    call strcpy_rsi_rdi

    ; Load the file
    call load_file
    test rax, rax
    jnz .exit_error

    ; Detect language from extension or shebang
    call detect_language

    jmp .file_loaded

.check_stdin:
    ; No filename, check if stdin is a pipe
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCGETS
    lea rdx, [orig_termios]
    syscall
    test rax, rax
    js .stdin_is_pipe
    ; stdin is a TTY, no file given
    jmp .usage

.stdin_is_pipe:
    mov qword [mode], MODE_PIPE
    call read_stdin
    call detect_language
    jmp .file_loaded

.usage:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_usage]
    mov rdx, err_usage_len
    syscall
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

.file_loaded:
    ; Build line index
    call build_line_index

    ; Check if stdout is a TTY
    sub rsp, 64
    mov rax, SYS_IOCTL
    mov rdi, 1
    mov esi, TCGETS
    mov rdx, rsp
    syscall
    test rax, rax
    js .stdout_not_tty
    mov qword [stdout_is_tty], 1
    jmp .stdout_check_done
.stdout_not_tty:
    mov qword [stdout_is_tty], 0
.stdout_check_done:
    add rsp, 64

    ; Dispatch by mode
    cmp qword [mode], MODE_PANE
    je .do_pane
    cmp qword [mode], MODE_PIPE
    je .do_pipe_or_pager

    ; Regular file: if stdout is TTY, use pager mode
    cmp qword [stdout_is_tty], 1
    je .do_pager
    ; stdout is pipe, just dump with colors
    jmp .do_cat

.do_pipe_or_pager:
    ; Stdin is a pipe — always cat-render. The pager reads keystrokes
    ; from fd 0, but fd 0 is the upstream pipe so there's no way for
    ; the user to drive it; previously this hung or dropped output
    ; entirely (e.g. `apt-cache search chrome | show`).
    jmp .do_cat

.do_pane:
    call render_pane
    jmp .exit_ok

.do_pager:
    call run_pager
    jmp .exit_ok

.do_cat:
    call render_cat
    jmp .exit_ok

.exit_ok:
    call cleanup
    xor edi, edi
    mov rax, SYS_EXIT
    syscall

.exit_error:
    call cleanup
    mov rdi, 1
    mov rax, SYS_EXIT
    syscall

; ══════════════════════════════════════════════════════════════════════
; File I/O
; ══════════════════════════════════════════════════════════════════════

; Load file via mmap. Returns 0 on success, -1 on error.
load_file:
    push rbx
    push r12

    ; Open file
    mov rax, SYS_OPEN
    lea rdi, [file_path]
    xor esi, esi             ; O_RDONLY
    xor edx, edx
    syscall
    test rax, rax
    js .lf_open_err
    mov rbx, rax             ; fd

    ; Fstat to get size
    mov rax, SYS_FSTAT
    mov rdi, rbx
    lea rsi, [stat_buf]
    syscall
    test rax, rax
    js .lf_stat_err

    mov r12, [stat_buf + 48] ; st_size
    mov [file_size], r12

    ; Handle empty file
    test r12, r12
    jz .lf_empty

    ; Mmap the file
    mov rax, SYS_MMAP
    xor edi, edi             ; addr = NULL
    mov rsi, r12             ; length = file_size
    mov rdx, PROT_READ       ; prot
    mov r10, MAP_PRIVATE     ; flags
    mov r8, rbx              ; fd
    xor r9d, r9d             ; offset = 0
    syscall
    test rax, rax
    js .lf_mmap_err
    mov [file_buf], rax

    ; Close fd
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall

    xor eax, eax
    pop r12
    pop rbx
    ret

.lf_empty:
    mov qword [file_buf], 0
    mov qword [file_size], 0
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
    xor eax, eax
    pop r12
    pop rbx
    ret

.lf_open_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_open]
    mov rdx, err_open_len
    syscall
    ; Print filename
    lea rdi, [file_path]
    call strlen
    mov rdx, rax
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [file_path]
    syscall
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [newline]
    mov rdx, 1
    syscall
    mov rax, -1
    pop r12
    pop rbx
    ret

.lf_stat_err:
    mov rax, SYS_CLOSE
    mov rdi, rbx
    syscall
.lf_mmap_err:
    mov rax, SYS_WRITE
    mov rdi, 2
    lea rsi, [err_mmap]
    mov rdx, err_mmap_len
    syscall
    mov rax, -1
    pop r12
    pop rbx
    ret

; Read all of stdin into pipe_buf
read_stdin:
    push rbx
    xor ebx, ebx            ; total bytes read
.rs_loop:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [pipe_buf + rbx]
    mov rdx, 4096
    ; Check remaining space
    mov rcx, MAX_PIPE_BUF
    sub rcx, rbx
    cmp rdx, rcx
    jle .rs_read
    mov rdx, rcx
    test rdx, rdx
    jle .rs_done
.rs_read:
    syscall
    test rax, rax
    jle .rs_done
    add rbx, rax
    jmp .rs_loop
.rs_done:
    mov [pipe_len], rbx
    lea rax, [pipe_buf]
    mov [file_buf], rax
    mov [file_size], rbx
    pop rbx
    ret

; Cleanup: munmap if needed
cleanup:
    cmp qword [mode], MODE_PIPE
    je .cl_done
    mov rax, [file_buf]
    test rax, rax
    jz .cl_done
    mov rdi, rax
    mov rsi, [file_size]
    test rsi, rsi
    jz .cl_done
    mov rax, SYS_MUNMAP
    syscall
.cl_done:
    ret

; ══════════════════════════════════════════════════════════════════════
; Line index builder
; ══════════════════════════════════════════════════════════════════════
build_line_index:
    push rbx
    push r12

    mov rsi, [file_buf]
    mov rcx, [file_size]
    test rcx, rcx
    jz .bli_empty

    ; First line starts at offset 0
    mov qword [line_offsets], 0
    mov qword [line_count], 1
    xor r12d, r12d             ; current offset

.bli_scan:
    cmp r12, rcx
    jge .bli_done
    mov rsi, [file_buf]
    cmp byte [rsi + r12], 10
    jne .bli_next
    ; Found newline, next line starts at r12+1
    mov rbx, [line_count]
    cmp rbx, MAX_LINES - 1
    jge .bli_done
    lea rax, [r12 + 1]
    mov [line_offsets + rbx*8], rax
    inc qword [line_count]
.bli_next:
    inc r12
    jmp .bli_scan

.bli_empty:
    mov qword [line_count], 0
.bli_done:
    ; Calculate lineno_width
    mov rax, [line_count]
    xor ecx, ecx
.bli_digits:
    inc ecx
    mov rbx, 10
    xor edx, edx
    div rbx
    test rax, rax
    jnz .bli_digits
    mov [lineno_width], rcx

    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Language detection from file extension
; ══════════════════════════════════════════════════════════════════════
detect_language:
    push rbx
    push r12

    mov qword [language], LANG_NONE
    mov qword [kw_table_ptr], 0
    mov qword [type_table_ptr], 0
    mov qword [comment_line_ptr], 0
    mov qword [comment_blk_open], 0
    mov qword [comment_blk_close], 0

    ; Find last '.' in file_path (but not before last '/')
    lea rdi, [file_path]
    call strlen
    mov rcx, rax
    test rcx, rcx
    jz .dl_try_shebang
    lea rdi, [file_path]
    add rdi, rcx
    mov r12, rdi             ; save end pointer
.dl_find_dot:
    dec rdi
    cmp rdi, file_path
    jl .dl_try_shebang
    cmp byte [rdi], '/'
    je .dl_try_shebang       ; hit directory separator, no extension
    cmp byte [rdi], '.'
    jne .dl_find_dot

    ; rdi points to ".ext"
    lea rbx, [ext_table]
.dl_check:
    mov rsi, [rbx]
    test rsi, rsi
    jz .dl_try_shebang
    push rdi
    call strcmp
    pop rdi
    test rax, rax
    jz .dl_match
    add rbx, 16
    jmp .dl_check

.dl_try_shebang:
    ; Check if file starts with "#!" and extract interpreter name
    mov rsi, [file_buf]
    test rsi, rsi
    jz .dl_done
    mov rcx, [file_size]
    cmp rcx, 3
    jl .dl_done
    cmp byte [rsi], '#'
    jne .dl_done
    cmp byte [rsi + 1], '!'
    jne .dl_done

    ; Find the last component of the shebang path (after last '/' or space)
    ; Scan first line to find interpreter name
    add rsi, 2               ; skip "#!"
    ; Skip spaces
.dl_sb_skip_space:
    cmp byte [rsi], ' '
    jne .dl_sb_find_name
    inc rsi
    jmp .dl_sb_skip_space
.dl_sb_find_name:
    ; Find last '/' before newline or end
    mov rdi, rsi              ; start of path
    mov r12, rsi              ; last component start
.dl_sb_scan:
    movzx eax, byte [rsi]
    test al, al
    jz .dl_sb_got_name
    cmp al, 10
    je .dl_sb_got_name
    cmp al, '/'
    jne .dl_sb_not_slash
    lea r12, [rsi + 1]       ; component starts after slash
.dl_sb_not_slash:
    cmp al, ' '
    je .dl_sb_got_name        ; space ends the interpreter path
    inc rsi
    jmp .dl_sb_scan
.dl_sb_got_name:
    ; r12 points to interpreter name (e.g., "ruby", "env")
    ; If name is "env", skip to next word (the actual interpreter)
    cmp dword [r12], 'env '
    jne .dl_sb_match
    ; Skip "env " and spaces
    add r12, 4
.dl_sb_skip_env:
    cmp byte [r12], ' '
    jne .dl_sb_match
    inc r12
    jmp .dl_sb_skip_env

.dl_sb_match:
    ; Compare r12 against shebang_table entries
    lea rbx, [shebang_table]
.dl_sb_check:
    mov rsi, [rbx]
    test rsi, rsi
    jz .dl_done
    ; Compare: check if r12 starts with the table entry
    mov rdi, r12
    push rbx
    xor ecx, ecx
.dl_sb_cmp:
    movzx eax, byte [rsi + rcx]
    test al, al
    jz .dl_sb_end_kw
    movzx edx, byte [rdi + rcx]
    cmp al, dl
    jne .dl_sb_next
    inc rcx
    jmp .dl_sb_cmp
.dl_sb_end_kw:
    ; Keyword ended, check word boundary in source
    movzx eax, byte [rdi + rcx]
    test al, al
    jz .dl_sb_found
    cmp al, 10
    je .dl_sb_found
    cmp al, ' '
    je .dl_sb_found
    ; Not a word boundary, not a match
.dl_sb_next:
    pop rbx
    add rbx, 16
    jmp .dl_sb_check
.dl_sb_found:
    pop rbx
    mov rax, [rbx + 8]       ; language ID
    jmp .dl_set_language

.dl_match:
    mov rax, [rbx + 8]      ; language ID

.dl_set_language:
    mov [language], rax

    ; Set keyword table
    mov rcx, [kw_dispatch + rax*8]
    mov [kw_table_ptr], rcx

    ; Set type table
    mov rcx, [tp_dispatch + rax*8]
    mov [type_table_ptr], rcx

    ; Set comment style
    imul rcx, rax, 24       ; 3 qwords per entry
    lea rdi, [comment_table + rcx]
    mov rax, [rdi]
    mov [comment_line_ptr], rax
    mov rax, [rdi + 8]
    mov [comment_blk_open], rax
    mov rax, [rdi + 16]
    mov [comment_blk_close], rax

.dl_done:
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Output buffer system
; ══════════════════════════════════════════════════════════════════════

out_reset:
    mov qword [out_pos], 0
    ret

out_flush:
    push rbx
    mov rdx, [out_pos]
    test rdx, rdx
    jz .of_done
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [out_buf]
    syscall
.of_done:
    mov qword [out_pos], 0
    pop rbx
    ret

; Append byte in al. When out_safe = 1, ESC and 8-bit C1 controls
; (DCS / CSI / OSC / PM / APC introducers) are replaced with '?'
; so a malicious file can't sneak terminal escape sequences past
; show into the parent terminal.
out_char:
    cmp byte [out_safe], 0
    je .oc_store
    cmp al, 0x1B                ; ESC
    je .oc_neutralise
    cmp al, 0x90                ; DCS
    je .oc_neutralise
    cmp al, 0x9B                ; CSI
    je .oc_neutralise
    cmp al, 0x9D                ; OSC
    je .oc_neutralise
    cmp al, 0x9E                ; PM
    je .oc_neutralise
    cmp al, 0x9F                ; APC
    je .oc_neutralise
.oc_store:
    mov rcx, [out_pos]
    cmp rcx, OUT_BUF_SIZE - 1
    jge .oc_flush
    mov [out_buf + rcx], al
    inc qword [out_pos]
    ret
.oc_neutralise:
    mov al, '?'
    jmp .oc_store
.oc_flush:
    push rax
    call out_flush
    pop rax
    mov [out_buf], al
    mov qword [out_pos], 1
    ret

; Append null-terminated string from rsi
out_str:
    push rbx
    mov rbx, rsi
.os_loop:
    movzx eax, byte [rbx]
    test al, al
    jz .os_done
    call out_char
    inc rbx
    jmp .os_loop
.os_done:
    pop rbx
    ret

; Append rdx bytes from rsi
out_bytes:
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdx
    xor ecx, ecx
.ob_loop:
    cmp rcx, r12
    jge .ob_done
    movzx eax, byte [rbx + rcx]
    push rcx
    call out_char
    pop rcx
    inc rcx
    jmp .ob_loop
.ob_done:
    pop r12
    pop rbx
    ret

; Append ESC[38;5;XXXm for 256-color in al. show's own ANSI must
; bypass the file-byte sanitizer or every colour escape would be
; replaced with '?'. Save out_safe, disable, emit, restore.
out_color:
    push rbx
    push r12
    movzx r12d, al
    mov bl, [out_safe]
    mov byte [out_safe], 0
    mov al, 27
    call out_char
    mov al, '['
    call out_char
    mov al, '3'
    call out_char
    mov al, '8'
    call out_char
    mov al, ';'
    call out_char
    mov al, '5'
    call out_char
    mov al, ';'
    call out_char
    mov rax, r12
    lea rdi, [num_buf]
    call itoa
    mov rdx, rax
    lea rsi, [num_buf]
    call out_bytes
    mov al, 'm'
    call out_char
    mov [out_safe], bl
    pop r12
    pop rbx
    ret

; Append reset sequence
out_reset_color:
    push rbx
    mov bl, [out_safe]
    mov byte [out_safe], 0
    lea rsi, [reset_seq]
    mov rdx, reset_seq_len
    call out_bytes
    mov [out_safe], bl
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Cat mode: output all lines with syntax highlighting
; ══════════════════════════════════════════════════════════════════════
render_cat:
    push rbx
    push r12
    push r13

    call out_reset
    mov qword [hl_state], ST_NORMAL
    mov qword [show_line_numbers], 1

    xor r12d, r12d             ; line index
.rc_loop:
    cmp r12, [line_count]
    jge .rc_done

    ; Line number
    cmp qword [show_line_numbers], 0
    je .rc_no_lineno
    mov al, COL_LINENO
    call out_color
    ; Right-justify line number
    mov rax, r12
    inc rax
    lea rdi, [num_buf]
    call itoa
    mov r13, rax             ; digit count
    ; Pad with spaces
    mov rcx, [lineno_width]
    sub rcx, r13
.rc_pad:
    test rcx, rcx
    jle .rc_pad_done
    mov al, ' '
    push rcx
    call out_char
    pop rcx
    dec rcx
    jmp .rc_pad
.rc_pad_done:
    lea rsi, [num_buf]
    mov rdx, r13
    call out_bytes
    ; Separator
    lea rsi, [lineno_sep]
    mov rdx, lineno_sep_len
    call out_bytes
.rc_no_lineno:

    ; Get line start and length
    mov rsi, [line_offsets + r12*8]
    add rsi, [file_buf]      ; absolute pointer
    ; Calculate line length
    mov rax, r12
    inc rax
    cmp rax, [line_count]
    jge .rc_last_line
    mov rcx, [line_offsets + rax*8]
    sub rcx, [line_offsets + r12*8]
    ; Strip trailing newline
    jz .rc_highlight
    dec rcx
    jmp .rc_highlight
.rc_last_line:
    mov rcx, [file_size]
    sub rcx, [line_offsets + r12*8]
    ; Strip trailing newline if present
    jz .rc_highlight
    push rsi
    add rsi, rcx
    dec rsi
    cmp byte [rsi], 10
    pop rsi
    jne .rc_highlight
    dec rcx

.rc_highlight:
    ; rsi = line start, rcx = line length
    call highlight_line

    call out_reset_color
    mov al, 10
    call out_char

    ; Flush periodically
    cmp qword [out_pos], 60000
    jl .rc_no_flush
    call out_flush
.rc_no_flush:

    inc r12
    jmp .rc_loop

.rc_done:
    call out_flush
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Pane mode: output range of lines
; ══════════════════════════════════════════════════════════════════════
render_pane:
    push rbx
    push r12
    push r13

    call out_reset
    mov qword [hl_state], ST_NORMAL
    mov qword [show_line_numbers], 0

    ; Default range: entire file
    mov r12, [pane_start_line]
    test r12, r12
    jnz .rp_have_start
    xor r12d, r12d
    jmp .rp_start_set
.rp_have_start:
    dec r12                  ; 1-indexed to 0-indexed
.rp_start_set:
    mov r13, [pane_end_line]
    test r13, r13
    jnz .rp_have_end
    mov r13, [line_count]
    jmp .rp_loop
.rp_have_end:
    cmp r13, [line_count]
    jle .rp_loop
    mov r13, [line_count]

.rp_loop:
    cmp r12, r13
    jge .rp_done

    ; Get line
    mov rsi, [line_offsets + r12*8]
    add rsi, [file_buf]
    mov rax, r12
    inc rax
    cmp rax, [line_count]
    jge .rp_last
    mov rcx, [line_offsets + rax*8]
    sub rcx, [line_offsets + r12*8]
    jz .rp_hl
    dec rcx
    jmp .rp_hl
.rp_last:
    mov rcx, [file_size]
    sub rcx, [line_offsets + r12*8]
    jz .rp_hl
    push rsi
    add rsi, rcx
    dec rsi
    cmp byte [rsi], 10
    pop rsi
    jne .rp_hl
    dec rcx
.rp_hl:
    call highlight_line
    call out_reset_color
    mov al, 10
    call out_char

    cmp qword [out_pos], 60000
    jl .rp_nf
    call out_flush
.rp_nf:
    inc r12
    jmp .rp_loop

.rp_done:
    call out_flush
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Pager mode
; ══════════════════════════════════════════════════════════════════════
run_pager:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save termios and enter raw mode
    call save_termios
    call enable_raw_mode
    call get_term_size

    ; Enter alt screen, clear, hide cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [alt_screen_on]
    mov rdx, alt_screen_on_len
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [clr_screen]
    mov rdx, clr_screen_len
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [hide_cursor]
    mov rdx, hide_cursor_len
    syscall

    mov qword [top_line], 0
    mov qword [left_col], 0
    mov qword [show_line_numbers], 1
    mov qword [search_active], 0

.pager_loop:
    ; Check SIGWINCH
    cmp qword [winch_flag], 0
    je .pg_no_winch
    mov qword [winch_flag], 0
    call get_term_size
.pg_no_winch:

    call render_screen

    ; Read key
    call read_key
    ; rax = key code

    cmp rax, 'q'
    je .pager_quit
    cmp rax, 'j'
    je .pg_down
    cmp rax, KEY_DOWN
    je .pg_down
    cmp rax, 'k'
    je .pg_up
    cmp rax, KEY_UP
    je .pg_up
    cmp rax, ' '
    je .pg_pgdn
    cmp rax, KEY_PGDN
    je .pg_pgdn
    cmp rax, 'b'
    je .pg_pgup
    cmp rax, KEY_PGUP
    je .pg_pgup
    cmp rax, 'g'
    je .pg_top
    cmp rax, KEY_HOME
    je .pg_top
    cmp rax, 'G'
    je .pg_bottom
    cmp rax, KEY_END
    je .pg_bottom
    cmp rax, '/'
    je .pg_search
    cmp rax, 'n'
    je .pg_search_next
    cmp rax, 'N'
    je .pg_search_prev
    cmp rax, 'l'
    je .pg_toggle_lineno
    cmp rax, KEY_RIGHT
    je .pg_right
    cmp rax, KEY_LEFT
    je .pg_left
    jmp .pager_loop

.pg_down:
    mov rax, [top_line]
    inc rax
    mov rcx, [line_count]
    mov rdx, [term_rows]
    sub rcx, rdx
    inc rcx
    cmp rax, rcx
    jge .pager_loop
    mov [top_line], rax
    jmp .pager_loop

.pg_up:
    cmp qword [top_line], 0
    je .pager_loop
    dec qword [top_line]
    jmp .pager_loop

.pg_pgdn:
    mov rax, [top_line]
    mov rcx, [term_rows]
    dec rcx
    add rax, rcx
    mov rcx, [line_count]
    mov rdx, [term_rows]
    sub rcx, rdx
    inc rcx
    cmp rax, rcx
    jl .pg_pgdn_ok
    mov rax, rcx
    dec rax
    test rax, rax
    jns .pg_pgdn_ok
    xor eax, eax
.pg_pgdn_ok:
    mov [top_line], rax
    jmp .pager_loop

.pg_pgup:
    mov rax, [top_line]
    mov rcx, [term_rows]
    dec rcx
    sub rax, rcx
    jns .pg_pgup_ok
    xor eax, eax
.pg_pgup_ok:
    mov [top_line], rax
    jmp .pager_loop

.pg_top:
    mov qword [top_line], 0
    jmp .pager_loop

.pg_bottom:
    mov rax, [line_count]
    mov rcx, [term_rows]
    sub rax, rcx
    inc rax
    test rax, rax
    jns .pg_bot_ok
    xor eax, eax
.pg_bot_ok:
    mov [top_line], rax
    jmp .pager_loop

.pg_toggle_lineno:
    xor qword [show_line_numbers], 1
    jmp .pager_loop

.pg_right:
    inc qword [left_col]
    jmp .pager_loop

.pg_left:
    cmp qword [left_col], 0
    je .pager_loop
    dec qword [left_col]
    jmp .pager_loop

.pg_search:
    ; TODO: search prompt
    jmp .pager_loop

.pg_search_next:
    ; TODO: search next
    jmp .pager_loop

.pg_search_prev:
    ; TODO: search prev
    jmp .pager_loop

.pager_quit:
    ; Leave alt screen, show cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [show_cursor]
    mov rdx, show_cursor_len
    syscall
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [alt_screen_off]
    mov rdx, alt_screen_off_len
    syscall

    call restore_termios

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; compute_line_vrows — given line bytes [rsi, rsi+rcx), return rax =
; number of visual rows the line will occupy under terminal soft-wrap
; (rounded up, minimum 1). UTF-8 continuation bytes don't count; tabs
; advance to the next 8-column stop.
;
; Effective width = term_cols minus the line-number prefix when line
; numbers are shown. We treat the prefix as eating from EVERY row's
; budget — slight over-count vs. reality (continuation rows have no
; prefix and could be wider), but err on the side of leaving a blank
; row instead of the line overflowing into the status bar.
; ══════════════════════════════════════════════════════════════════════
compute_line_vrows:
    push rbx
    push r8
    push r9
    push r10

    mov r10, rsi
    add r10, rcx                ; r10 = end pointer

    mov rbx, [term_cols]
    cmp qword [show_line_numbers], 0
    je .cv_have_cols
    mov rax, [lineno_width]
    add rax, 3                  ; " | " separator
    sub rbx, rax
.cv_have_cols:
    test rbx, rbx
    jle .cv_one                 ; degenerate term too narrow

    xor r8d, r8d                  ; col on current row
    mov r9, 1                   ; rows so far
.cv_loop:
    cmp rsi, r10
    jge .cv_done
    movzx eax, byte [rsi]
    inc rsi
    ; Skip UTF-8 continuation bytes (0x80..0xBF)
    cmp al, 0x80
    jb .cv_visible
    cmp al, 0xC0
    jb .cv_loop
.cv_visible:
    cmp al, 9                   ; tab → next 8-column stop
    jne .cv_normal
    or r8, 7
    inc r8
    jmp .cv_check
.cv_normal:
    inc r8
.cv_check:
    cmp r8, rbx
    jl .cv_loop
    inc r9
    xor r8d, r8d
    jmp .cv_loop
.cv_done:
    mov rax, r9
    test r8, r8
    jnz .cv_ret
    ; Last char wrapped exactly to a row boundary — that row counted
    ; via the inc r9 above but no content was drawn on it. Don't
    ; subtract: a line of exactly N×width still occupies N rows.
    cmp rax, 1
    jle .cv_ret
    dec rax
.cv_ret:
    pop r10
    pop r9
    pop r8
    pop rbx
    ret
.cv_one:
    mov rax, 1
    pop r10
    pop r9
    pop r8
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Screen rendering (pager mode)
; ══════════════════════════════════════════════════════════════════════
render_screen:
    push rbx
    push r12
    push r13
    push r14

    call out_reset
    ; Cursor home
    lea rsi, [cursor_home]
    mov rdx, cursor_home_len
    call out_bytes

    mov qword [hl_state], ST_NORMAL
    mov r14, [term_rows]
    dec r14                  ; last row = status bar
    mov r12, [top_line]

.rs_line_loop:
    test r14, r14
    jle .rs_status_bar

    cmp r12, [line_count]
    jge .rs_empty_line

    ; --- Compute line bounds (rsi=start, rcx=length excluding trailing \n) ---
    mov rsi, [line_offsets + r12*8]
    add rsi, [file_buf]
    mov rax, r12
    inc rax
    cmp rax, [line_count]
    jge .rs_compute_last
    mov rcx, [line_offsets + rax*8]
    sub rcx, [line_offsets + r12*8]
    jz .rs_have_bounds
    dec rcx
    jmp .rs_have_bounds
.rs_compute_last:
    mov rcx, [file_size]
    sub rcx, [line_offsets + r12*8]
    jz .rs_have_bounds
    push rsi
    add rsi, rcx
    dec rsi
    cmp byte [rsi], 10
    pop rsi
    jne .rs_have_bounds
    dec rcx
.rs_have_bounds:

    ; --- Compute visual rows the line will occupy under terminal soft-wrap.
    ;     Stop the render loop if the line won't fully fit in the remaining
    ;     budget — the remaining rows are filled with `~` placeholders so
    ;     the status bar always lands on the bottom row. ---
    push rsi
    push rcx
    call compute_line_vrows
    pop rcx
    pop rsi
    cmp rax, r14
    jg .rs_overflow_fill
    push rax                         ; save vrows across rendering

    ; --- Line number prefix (if enabled) ---
    push rsi
    push rcx
    cmp qword [show_line_numbers], 0
    je .rs_no_ln_pop
    mov al, COL_LINENO
    call out_color
    mov rax, r12
    inc rax
    lea rdi, [num_buf]
    call itoa
    mov r13, rax
    mov rcx, [lineno_width]
    sub rcx, r13
.rs_pad:
    test rcx, rcx
    jle .rs_pad_done
    mov al, ' '
    push rcx
    call out_char
    pop rcx
    dec rcx
    jmp .rs_pad
.rs_pad_done:
    lea rsi, [num_buf]
    mov rdx, r13
    call out_bytes
    lea rsi, [lineno_sep]
    mov rdx, lineno_sep_len
    call out_bytes
.rs_no_ln_pop:
    pop rcx
    pop rsi

    ; --- Highlight + emit line content + EOL ---
    call highlight_line
    call out_reset_color
    lea rsi, [clr_eol]
    mov rdx, clr_eol_len
    call out_bytes
    mov al, 10
    call out_char

    pop rax                          ; restore vrows
    sub r14, rax                     ; consume the rows the line occupied
    inc r12
    jmp .rs_line_loop

.rs_overflow_fill:
    ; The next logical line needs more visual rows than the remaining
    ; budget. Don't render it (would overflow into the status bar);
    ; fill remaining rows with `~` and exit to the status bar. r12 is
    ; left pointing at the first not-rendered line so end_line in the
    ; status bar correctly reflects how far we got.
.rs_of_loop:
    test r14, r14
    jle .rs_status_bar
    mov al, COL_LINENO
    call out_color
    mov al, '~'
    call out_char
    call out_reset_color
    lea rsi, [clr_eol]
    mov rdx, clr_eol_len
    call out_bytes
    mov al, 10
    call out_char
    dec r14
    jmp .rs_of_loop

.rs_empty_line:
    ; Past end of file: show ~
    mov al, COL_LINENO
    call out_color
    mov al, '~'
    call out_char
    call out_reset_color
    lea rsi, [clr_eol]
    mov rdx, clr_eol_len
    call out_bytes
    mov al, 10
    call out_char
    dec r14
    inc r12
    jmp .rs_line_loop

.rs_status_bar:
    ; Hide cursor during render
    lea rsi, [hide_cursor]
    mov rdx, hide_cursor_len
    call out_bytes

    ; Reverse video
    lea rsi, [reverse_seq]
    mov rdx, reverse_seq_len
    call out_bytes

    ; Track column position in r13
    xor r13d, r13d

    ; Filename
    lea rdi, [file_path]
    call strlen
    mov r13, rax
    lea rsi, [file_path]
    call out_str

    ; "  L"
    mov al, ' '
    call out_char
    mov al, ' '
    call out_char
    mov al, 'L'
    call out_char
    add r13, 3

    ; Start line
    mov rax, [top_line]
    inc rax
    lea rdi, [num_buf]
    call itoa
    add r13, rax
    lea rsi, [num_buf]
    mov rdx, rax
    call out_bytes

    ; "-"
    mov al, '-'
    call out_char
    inc r13

    ; End line
    mov rax, r12
    cmp rax, [line_count]
    jle .rs_sb_lastok
    mov rax, [line_count]
.rs_sb_lastok:
    lea rdi, [num_buf]
    call itoa
    add r13, rax
    lea rsi, [num_buf]
    mov rdx, rax
    call out_bytes

    ; "/"
    mov al, '/'
    call out_char
    inc r13

    ; Total lines
    mov rax, [line_count]
    lea rdi, [num_buf]
    call itoa
    add r13, rax
    lea rsi, [num_buf]
    mov rdx, rax
    call out_bytes

    ; Pad with spaces until version position
    ; version = "show v0.1.0 " = 12 chars
    ; pad = term_cols - r13 - 12
    mov rax, [term_cols]
    sub rax, r13
    sub rax, 12
    ; Clamp to 0 minimum
    jle .rs_sb_no_pad
    mov rcx, rax
.rs_sb_pad:
    mov al, ' '
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .rs_sb_pad
.rs_sb_no_pad:

    ; Version string
    lea rsi, [.rs_version]
    call out_str

    call out_reset_color
    call out_flush

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

.rs_version: db "show v0.1.0 ", 0

; ══════════════════════════════════════════════════════════════════════
; Syntax highlighting engine
; Input: rsi = line start, rcx = line length
; Appends highlighted content to out_buf
; ══════════════════════════════════════════════════════════════════════
highlight_line:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Stash and enable file-byte sanitization (only when stdout is
    ; actually a terminal — pipes / file redirects keep the raw
    ; bytes so `show foo > foo.ansi` still produces a valid colour
    ; capture).
    movzx ebx, byte [out_safe]
    push rbx
    movzx ebx, byte [tty_out]
    mov [out_safe], bl

    mov r12, rsi             ; line start
    mov r13, rcx             ; line length
    xor r14d, r14d             ; current position in line
    mov r15, [hl_state]      ; highlight state

    ; No language? Just output plain
    cmp qword [language], LANG_NONE
    je .hl_plain

    ; Check for block comment continuation
    cmp r15, ST_COMMENT_BLOCK
    je .hl_in_block_comment

    ; Check for preprocessor line (# at start for C/C#, %define/%macro for ASM)
    call .hl_check_preprocessor
    test rax, rax
    jnz .hl_preproc_line

.hl_char_loop:
    cmp r14, r13
    jge .hl_done

    movzx eax, byte [r12 + r14]

    ; State machine
    cmp r15, ST_STRING_DQ
    je .hl_in_string_dq
    cmp r15, ST_STRING_SQ
    je .hl_in_string_sq
    cmp r15, ST_COMMENT_LINE
    je .hl_in_line_comment

    ; ST_NORMAL: check for various starts

    ; Check line comment
    mov rdi, [comment_line_ptr]
    test rdi, rdi
    jz .hl_no_line_comment
    call .hl_check_prefix
    test rax, rax
    jnz .hl_start_line_comment
.hl_no_line_comment:

    ; Check block comment open
    mov rdi, [comment_blk_open]
    test rdi, rdi
    jz .hl_no_block_open
    call .hl_check_prefix
    test rax, rax
    jnz .hl_start_block_comment
.hl_no_block_open:

    ; Reload current char (clobbered by check_prefix calls above)
    movzx eax, byte [r12 + r14]

    ; Check string start
    cmp al, '"'
    je .hl_start_string_dq
    cmp al, 0x27             ; single quote
    je .hl_start_string_sq

    ; Check number at word boundary
    cmp al, '0'
    jb .hl_not_number
    cmp al, '9'
    ja .hl_not_number
    ; Check word boundary (start of line or prev char is not alnum)
    test r14, r14
    jz .hl_start_number
    movzx ebx, byte [r12 + r14 - 1]
    call .hl_is_word_char_bl
    test rax, rax
    jz .hl_start_number
.hl_not_number:

    ; Check keyword at word boundary
    cmp qword [kw_table_ptr], 0
    je .hl_normal_char
    ; Must be at word boundary
    test r14, r14
    jz .hl_try_keyword
    movzx ebx, byte [r12 + r14 - 1]
    call .hl_is_word_char_bl
    test rax, rax
    jnz .hl_normal_char
.hl_try_keyword:
    call .hl_check_keyword
    test rax, rax
    jnz .hl_emit_keyword

    ; Check for type name
    call .hl_check_type
    test rax, rax
    jnz .hl_emit_type

    ; Check for function call (word followed by '(')
    call .hl_check_func
    test rax, rax
    jnz .hl_emit_func

    ; Check for operator
    movzx eax, byte [r12 + r14]
    call .hl_is_operator
    test rax, rax
    jnz .hl_emit_operator

.hl_normal_char:
    ; Handle tab
    cmp byte [r12 + r14], 9
    je .hl_tab
    ; Regular char
    movzx eax, byte [r12 + r14]
    call out_char
    inc r14
    jmp .hl_char_loop

.hl_tab:
    mov al, ' '
    mov rcx, TAB_WIDTH
.hl_tab_loop:
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .hl_tab_loop
    inc r14
    jmp .hl_char_loop

; ── String handling ──
.hl_start_string_dq:
    movzx eax, byte [th_string]
    call out_color
    mov r15, ST_STRING_DQ
    movzx eax, byte [r12 + r14]
    call out_char
    inc r14
    jmp .hl_char_loop

.hl_start_string_sq:
    movzx eax, byte [th_string]
    call out_color
    mov r15, ST_STRING_SQ
    movzx eax, byte [r12 + r14]
    call out_char
    inc r14
    jmp .hl_char_loop

.hl_in_string_dq:
    movzx eax, byte [r12 + r14]
    cmp al, '\'
    jne .hl_sdq_not_escape
    ; Escape: output this and next char
    call out_char
    inc r14
    cmp r14, r13
    jge .hl_done
    movzx eax, byte [r12 + r14]
    call out_char
    inc r14
    jmp .hl_char_loop
.hl_sdq_not_escape:
    call out_char
    inc r14
    cmp al, '"'
    jne .hl_char_loop
    ; End of string
    call out_reset_color
    mov r15, ST_NORMAL
    jmp .hl_char_loop

.hl_in_string_sq:
    movzx eax, byte [r12 + r14]
    cmp al, '\'
    jne .hl_ssq_not_escape
    call out_char
    inc r14
    cmp r14, r13
    jge .hl_done
    movzx eax, byte [r12 + r14]
    call out_char
    inc r14
    jmp .hl_char_loop
.hl_ssq_not_escape:
    call out_char
    inc r14
    cmp al, 0x27
    jne .hl_char_loop
    call out_reset_color
    mov r15, ST_NORMAL
    jmp .hl_char_loop

; ── Comment handling ──
.hl_start_line_comment:
    movzx eax, byte [th_comment]
    call out_color
    mov r15, ST_COMMENT_LINE
    jmp .hl_char_loop

.hl_in_line_comment:
    movzx eax, byte [r12 + r14]
    cmp al, 9
    jne .hl_lc_not_tab
    mov al, ' '
    mov rcx, TAB_WIDTH
.hl_lc_tab:
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .hl_lc_tab
    inc r14
    jmp .hl_char_loop
.hl_lc_not_tab:
    call out_char
    inc r14
    jmp .hl_char_loop

.hl_start_block_comment:
    movzx eax, byte [th_comment]
    call out_color
    mov r15, ST_COMMENT_BLOCK
    jmp .hl_in_block_comment

.hl_in_block_comment:
    cmp r14, r13
    jge .hl_done
    ; Check for block close
    mov rdi, [comment_blk_close]
    test rdi, rdi
    jz .hl_bc_char
    call .hl_check_prefix
    test rax, rax
    jz .hl_bc_char
    ; Found close, output it and reset
    mov rdi, [comment_blk_close]
    call strlen
    mov rcx, rax
.hl_bc_close_loop:
    test rcx, rcx
    jz .hl_bc_closed
    movzx eax, byte [r12 + r14]
    push rcx
    call out_char
    pop rcx
    inc r14
    dec rcx
    jmp .hl_bc_close_loop
.hl_bc_closed:
    call out_reset_color
    mov r15, ST_NORMAL
    jmp .hl_char_loop
.hl_bc_char:
    movzx eax, byte [r12 + r14]
    cmp al, 9
    jne .hl_bc_not_tab
    mov al, ' '
    mov rcx, TAB_WIDTH
.hl_bc_tab:
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .hl_bc_tab
    inc r14
    jmp .hl_in_block_comment
.hl_bc_not_tab:
    call out_char
    inc r14
    jmp .hl_in_block_comment

; ── Number handling ──
.hl_start_number:
    movzx eax, byte [th_number]
    call out_color
.hl_number_loop:
    cmp r14, r13
    jge .hl_number_done
    movzx eax, byte [r12 + r14]
    cmp al, '0'
    jb .hl_number_done
    cmp al, '9'
    ja .hl_check_hex
    call out_char
    inc r14
    jmp .hl_number_loop
.hl_check_hex:
    cmp al, 'x'
    je .hl_number_hex
    cmp al, 'X'
    je .hl_number_hex
    cmp al, '.'
    je .hl_number_hex
    cmp al, 'a'
    jb .hl_number_done
    cmp al, 'f'
    jbe .hl_number_hex
    cmp al, 'A'
    jb .hl_number_done
    cmp al, 'F'
    jbe .hl_number_hex
    jmp .hl_number_done
.hl_number_hex:
    call out_char
    inc r14
    jmp .hl_number_loop
.hl_number_done:
    call out_reset_color
    jmp .hl_char_loop

; ── Keyword handling ──
.hl_emit_keyword:
    ; rax = keyword length
    push rax
    movzx eax, byte [th_keyword]
    call out_color
    pop rcx
.hl_kw_emit:
    test rcx, rcx
    jz .hl_kw_done
    movzx eax, byte [r12 + r14]
    push rcx
    call out_char
    pop rcx
    inc r14
    dec rcx
    jmp .hl_kw_emit
.hl_kw_done:
    call out_reset_color
    jmp .hl_char_loop

; ── Type handling ──
.hl_emit_type:
    push rax
    movzx eax, byte [th_type]
    call out_color
    pop rcx
.hl_tp_emit:
    test rcx, rcx
    jz .hl_tp_done
    movzx eax, byte [r12 + r14]
    push rcx
    call out_char
    pop rcx
    inc r14
    dec rcx
    jmp .hl_tp_emit
.hl_tp_done:
    call out_reset_color
    jmp .hl_char_loop

; ── Function call handling ──
.hl_emit_func:
    push rax
    movzx eax, byte [th_func]
    call out_color
    pop rcx
.hl_fn_emit:
    test rcx, rcx
    jz .hl_fn_done
    movzx eax, byte [r12 + r14]
    push rcx
    call out_char
    pop rcx
    inc r14
    dec rcx
    jmp .hl_fn_emit
.hl_fn_done:
    call out_reset_color
    jmp .hl_char_loop

; ── Operator handling ──
.hl_emit_operator:
    ; rax = operator length (1 or 2)
    push rax
    movzx eax, byte [th_punct]
    call out_color
    pop rcx
.hl_op_emit:
    test rcx, rcx
    jz .hl_op_done
    movzx eax, byte [r12 + r14]
    push rcx
    call out_char
    pop rcx
    inc r14
    dec rcx
    jmp .hl_op_emit
.hl_op_done:
    call out_reset_color
    jmp .hl_char_loop

; ── Preprocessor line handling ──
.hl_preproc_line:
    movzx eax, byte [th_preproc]
    call out_color
.hl_preproc_loop:
    cmp r14, r13
    jge .hl_preproc_end
    movzx eax, byte [r12 + r14]
    cmp al, 9
    jne .hl_pp_not_tab
    mov al, ' '
    mov rcx, TAB_WIDTH
.hl_pp_tab:
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .hl_pp_tab
    inc r14
    jmp .hl_preproc_loop
.hl_pp_not_tab:
    call out_char
    inc r14
    jmp .hl_preproc_loop
.hl_preproc_end:
    call out_reset_color
    jmp .hl_done

; ── Plain output (no language) ──
.hl_plain:
.hl_plain_loop:
    cmp r14, r13
    jge .hl_done
    movzx eax, byte [r12 + r14]
    cmp al, 9
    jne .hl_plain_not_tab
    mov al, ' '
    mov rcx, TAB_WIDTH
.hl_plain_tab:
    push rcx
    call out_char
    pop rcx
    dec rcx
    jnz .hl_plain_tab
    inc r14
    jmp .hl_plain_loop
.hl_plain_not_tab:
    call out_char
    inc r14
    jmp .hl_plain_loop

.hl_done:
    ; Persist block comment state; reset line comment state
    cmp r15, ST_COMMENT_LINE
    jne .hl_save_state
    mov r15, ST_NORMAL
.hl_save_state:
    mov [hl_state], r15

    ; Restore previous out_safe value (pushed at function entry).
    pop rbx
    mov [out_safe], bl

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ── Helper: check if string at rdi matches at current position ──
; Returns rax = length if match, 0 if not
.hl_check_prefix:
    push rbx
    push rcx
    xor ecx, ecx
.hl_cp_loop:
    movzx eax, byte [rdi + rcx]
    test al, al
    jz .hl_cp_match
    mov rbx, r14
    add rbx, rcx
    cmp rbx, r13
    jge .hl_cp_no
    mov rbx, r14
    add rbx, rcx
    movzx ebx, byte [r12 + rbx]
    cmp al, bl
    jne .hl_cp_no
    inc rcx
    jmp .hl_cp_loop
.hl_cp_match:
    mov rax, rcx
    pop rcx
    pop rbx
    ret
.hl_cp_no:
    xor eax, eax
    pop rcx
    pop rbx
    ret

; ── Helper: check if bl is a word char (alnum or _) ──
; Returns rax=1 if word char, 0 if not
.hl_is_word_char_bl:
    cmp bl, '_'
    je .hl_wc_yes
    cmp bl, 'a'
    jb .hl_wc_check_upper
    cmp bl, 'z'
    jbe .hl_wc_yes
.hl_wc_check_upper:
    cmp bl, 'A'
    jb .hl_wc_check_digit
    cmp bl, 'Z'
    jbe .hl_wc_yes
.hl_wc_check_digit:
    cmp bl, '0'
    jb .hl_wc_no
    cmp bl, '9'
    jbe .hl_wc_yes
.hl_wc_no:
    xor eax, eax
    ret
.hl_wc_yes:
    mov eax, 1
    ret

; ── Helper: check keyword match at current position ──
; Returns rax = keyword length if matched, 0 if not
.hl_check_keyword:
    push rbx
    push rcx
    push rdx
    push rsi

    ; First, find word length at current position
    xor ecx, ecx
    mov rsi, r14
.hl_ck_wordlen:
    mov rax, rsi
    add rax, rcx
    cmp rax, r13
    jge .hl_ck_got_wordlen
    mov rbx, rsi
    add rbx, rcx
    movzx ebx, byte [r12 + rbx]
    cmp bl, '_'
    je .hl_ck_wl_next
    cmp bl, 'a'
    jb .hl_ck_wl_upper
    cmp bl, 'z'
    jbe .hl_ck_wl_next
.hl_ck_wl_upper:
    cmp bl, 'A'
    jb .hl_ck_wl_digit
    cmp bl, 'Z'
    jbe .hl_ck_wl_next
.hl_ck_wl_digit:
    cmp bl, '0'
    jb .hl_ck_got_wordlen
    cmp bl, '9'
    jbe .hl_ck_wl_next
    jmp .hl_ck_got_wordlen
.hl_ck_wl_next:
    inc rcx
    jmp .hl_ck_wordlen
.hl_ck_got_wordlen:
    ; rcx = word length
    test rcx, rcx
    jz .hl_ck_no

    ; Walk keyword table
    mov rdx, [kw_table_ptr]
.hl_ck_kw_loop:
    cmp byte [rdx], 0       ; double-null = end of table
    je .hl_ck_no
    ; Compare keyword with our word
    push rcx
    push rdx
    xor ebx, ebx
.hl_ck_cmp:
    movzx eax, byte [rdx + rbx]
    test al, al
    jz .hl_ck_end_kw
    cmp rbx, rcx
    jge .hl_ck_kw_longer
    push rcx
    mov rcx, r14
    add rcx, rbx
    cmp al, [r12 + rcx]
    pop rcx
    jne .hl_ck_kw_next
    inc rbx
    jmp .hl_ck_cmp
.hl_ck_end_kw:
    ; Keyword ended. Check if word also ended (same length)
    cmp rbx, rcx
    jne .hl_ck_kw_next
    ; Match!
    pop rdx
    pop rcx
    mov rax, rcx
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.hl_ck_kw_longer:
.hl_ck_kw_next:
    pop rdx
    pop rcx
    ; Advance to next keyword (skip past null)
.hl_ck_skip:
    cmp byte [rdx], 0
    je .hl_ck_next_kw
    inc rdx
    jmp .hl_ck_skip
.hl_ck_next_kw:
    inc rdx                  ; skip the null
    jmp .hl_ck_kw_loop

.hl_ck_no:
    xor eax, eax
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ── Helper: check if word matches a type table entry ──
; Same logic as hl_check_keyword but uses type_table_ptr
; Returns rax = word length if matched, 0 if not
.hl_check_type:
    push rbx
    push rcx
    push rdx
    push rsi

    cmp qword [type_table_ptr], 0
    je .hl_ct_no

    ; Find word length at current position
    xor ecx, ecx
    mov rsi, r14
.hl_ct_wordlen:
    mov rax, rsi
    add rax, rcx
    cmp rax, r13
    jge .hl_ct_got_wl
    mov rbx, rsi
    add rbx, rcx
    movzx ebx, byte [r12 + rbx]
    cmp bl, '_'
    je .hl_ct_wl_next
    cmp bl, 'a'
    jb .hl_ct_wl_upper
    cmp bl, 'z'
    jbe .hl_ct_wl_next
.hl_ct_wl_upper:
    cmp bl, 'A'
    jb .hl_ct_wl_digit
    cmp bl, 'Z'
    jbe .hl_ct_wl_next
.hl_ct_wl_digit:
    cmp bl, '0'
    jb .hl_ct_got_wl
    cmp bl, '9'
    jbe .hl_ct_wl_next
    jmp .hl_ct_got_wl
.hl_ct_wl_next:
    inc rcx
    jmp .hl_ct_wordlen
.hl_ct_got_wl:
    test rcx, rcx
    jz .hl_ct_no

    ; Walk type table
    mov rdx, [type_table_ptr]
.hl_ct_loop:
    cmp byte [rdx], 0
    je .hl_ct_no
    push rcx
    push rdx
    xor ebx, ebx
.hl_ct_cmp:
    movzx eax, byte [rdx + rbx]
    test al, al
    jz .hl_ct_end_tp
    cmp rbx, rcx
    jge .hl_ct_tp_next
    push rcx
    mov rcx, r14
    add rcx, rbx
    cmp al, [r12 + rcx]
    pop rcx
    jne .hl_ct_tp_next
    inc rbx
    jmp .hl_ct_cmp
.hl_ct_end_tp:
    cmp rbx, rcx
    jne .hl_ct_tp_next
    ; Match
    pop rdx
    pop rcx
    mov rax, rcx
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret
.hl_ct_tp_next:
    pop rdx
    pop rcx
.hl_ct_skip:
    cmp byte [rdx], 0
    je .hl_ct_adv
    inc rdx
    jmp .hl_ct_skip
.hl_ct_adv:
    inc rdx
    jmp .hl_ct_loop
.hl_ct_no:
    xor eax, eax
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ── Helper: check if word is followed by '(' (function call) ──
; Returns rax = word length if function call, 0 if not
.hl_check_func:
    push rbx
    push rcx

    ; Find word length
    xor ecx, ecx
    mov rbx, r14
.hl_cf_wl:
    mov rax, rbx
    add rax, rcx
    cmp rax, r13
    jge .hl_cf_got_wl
    mov rax, rbx
    add rax, rcx
    movzx eax, byte [r12 + rax]
    cmp al, '_'
    je .hl_cf_wl_next
    cmp al, 'a'
    jb .hl_cf_wl_upper
    cmp al, 'z'
    jbe .hl_cf_wl_next
.hl_cf_wl_upper:
    cmp al, 'A'
    jb .hl_cf_wl_digit
    cmp al, 'Z'
    jbe .hl_cf_wl_next
.hl_cf_wl_digit:
    cmp al, '0'
    jb .hl_cf_got_wl
    cmp al, '9'
    jbe .hl_cf_wl_next
    jmp .hl_cf_got_wl
.hl_cf_wl_next:
    inc rcx
    jmp .hl_cf_wl
.hl_cf_got_wl:
    ; rcx = word length
    cmp rcx, 1
    jl .hl_cf_no
    ; Check if next char after word is '('
    mov rax, r14
    add rax, rcx
    cmp rax, r13
    jge .hl_cf_no
    cmp byte [r12 + rax], '('
    jne .hl_cf_no
    mov rax, rcx
    pop rcx
    pop rbx
    ret
.hl_cf_no:
    xor eax, eax
    pop rcx
    pop rbx
    ret

; ── Helper: check if current char is an operator, return length (2 or 1) or 0 ──
.hl_is_operator:
    push rbx
    push rcx
    push rdx
    ; al = current char
    movzx ebx, al
    ; Check if it's in op_chars
    lea rdx, [op_chars]
.hl_op_scan:
    movzx ecx, byte [rdx]
    test cl, cl
    jz .hl_op_not
    cmp bl, cl
    je .hl_op_found
    inc rdx
    jmp .hl_op_scan
.hl_op_found:
    ; Check for 2-char operator first
    mov rax, r14
    inc rax
    cmp rax, r13
    jge .hl_op_single
    movzx ecx, byte [r12 + r14 + 1]
    ; Try each double operator
    lea rdx, [op_doubles]
.hl_op_dbl_loop:
    cmp byte [rdx], 0
    je .hl_op_single
    cmp bl, [rdx]
    jne .hl_op_dbl_next
    cmp cl, [rdx + 1]
    jne .hl_op_dbl_next
    ; Match
    mov eax, 2
    pop rdx
    pop rcx
    pop rbx
    ret
.hl_op_dbl_next:
    ; Skip to next entry (past null)
    inc rdx
    inc rdx
    inc rdx
    jmp .hl_op_dbl_loop
.hl_op_single:
    mov eax, 1
    pop rdx
    pop rcx
    pop rbx
    ret
.hl_op_not:
    ; Also check colon-colon specifically
    cmp bl, ':'
    jne .hl_op_zero
    mov rax, r14
    inc rax
    cmp rax, r13
    jge .hl_op_zero
    cmp byte [r12 + r14 + 1], ':'
    jne .hl_op_zero
    mov eax, 2
    pop rdx
    pop rcx
    pop rbx
    ret
.hl_op_zero:
    xor eax, eax
    pop rdx
    pop rcx
    pop rbx
    ret

; ── Helper: check if line starts with preprocessor directive ──
; Returns rax=1 if preprocessor line, 0 if not
.hl_check_preprocessor:
    push rbx
    test r13, r13
    jz .hl_pp_no
    ; Skip leading whitespace
    xor ebx, ebx
.hl_pp_skip_ws:
    cmp rbx, r13
    jge .hl_pp_no
    cmp byte [r12 + rbx], ' '
    je .hl_pp_ws_next
    cmp byte [r12 + rbx], 9
    je .hl_pp_ws_next
    jmp .hl_pp_check
.hl_pp_ws_next:
    inc rbx
    jmp .hl_pp_skip_ws
.hl_pp_check:
    ; For C and C#: check for '#' followed by alpha
    mov rax, [language]
    cmp rax, LANG_C
    je .hl_pp_check_hash
    cmp rax, LANG_CSHARP
    je .hl_pp_check_hash
    ; For ASM: check for '%'
    cmp rax, LANG_ASM
    je .hl_pp_check_pct
    jmp .hl_pp_no
.hl_pp_check_hash:
    cmp byte [r12 + rbx], '#'
    jne .hl_pp_no
    ; Verify next char is alpha (not a comment-only line)
    inc rbx
    cmp rbx, r13
    jge .hl_pp_no
    movzx eax, byte [r12 + rbx]
    cmp al, 'a'
    jb .hl_pp_upper
    cmp al, 'z'
    jbe .hl_pp_yes
.hl_pp_upper:
    cmp al, 'A'
    jb .hl_pp_no
    cmp al, 'Z'
    jbe .hl_pp_yes
    jmp .hl_pp_no
.hl_pp_check_pct:
    cmp byte [r12 + rbx], '%'
    jne .hl_pp_no
    ; Check next chars for "define" or "macro" or "include" etc.
    inc rbx
    cmp rbx, r13
    jge .hl_pp_no
    movzx eax, byte [r12 + rbx]
    cmp al, 'd'
    je .hl_pp_yes
    cmp al, 'm'
    je .hl_pp_yes
    cmp al, 'i'
    je .hl_pp_yes
    cmp al, 'e'
    je .hl_pp_yes
    cmp al, 'u'
    je .hl_pp_yes
    cmp al, 'a'
    je .hl_pp_yes
    jmp .hl_pp_no
.hl_pp_yes:
    mov eax, 1
    pop rbx
    ret
.hl_pp_no:
    xor eax, eax
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Key input (pager mode)
; ══════════════════════════════════════════════════════════════════════
read_key:
    push rbx
.rk_retry:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    cmp rax, -4              ; EINTR
    je .rk_retry
    test rax, rax
    jle .rk_eof

    movzx eax, byte [tmp_buf]
    cmp al, 27
    je .rk_escape
    pop rbx
    ret

.rk_escape:
    ; Read next byte
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .rk_esc_only
    movzx eax, byte [tmp_buf]
    cmp al, '['
    jne .rk_esc_only

    ; CSI sequence
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    test rax, rax
    jle .rk_esc_only
    movzx eax, byte [tmp_buf]
    cmp al, 'A'
    je .rk_up
    cmp al, 'B'
    je .rk_down
    cmp al, 'C'
    je .rk_right
    cmp al, 'D'
    je .rk_left
    cmp al, 'H'
    je .rk_home
    cmp al, 'F'
    je .rk_end
    cmp al, '5'
    je .rk_maybe_pgup
    cmp al, '6'
    je .rk_maybe_pgdn
    ; Unknown, ignore
.rk_esc_only:
    mov rax, 27
    pop rbx
    ret
.rk_up:
    mov rax, KEY_UP
    pop rbx
    ret
.rk_down:
    mov rax, KEY_DOWN
    pop rbx
    ret
.rk_right:
    mov rax, KEY_RIGHT
    pop rbx
    ret
.rk_left:
    mov rax, KEY_LEFT
    pop rbx
    ret
.rk_home:
    mov rax, KEY_HOME
    pop rbx
    ret
.rk_end:
    mov rax, KEY_END
    pop rbx
    ret
.rk_maybe_pgup:
    ; Read the '~'
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    mov rax, KEY_PGUP
    pop rbx
    ret
.rk_maybe_pgdn:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [tmp_buf]
    mov rdx, 1
    syscall
    mov rax, KEY_PGDN
    pop rbx
    ret
.rk_eof:
    mov rax, 'q'             ; treat EOF as quit
    pop rbx
    ret

; ══════════════════════════════════════════════════════════════════════
; Terminal setup
; ══════════════════════════════════════════════════════════════════════
save_termios:
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCGETS
    lea rdx, [orig_termios]
    syscall
    ret

restore_termios:
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [orig_termios]
    syscall
    ret

enable_raw_mode:
    lea rsi, [orig_termios]
    lea rdi, [raw_termios]
    mov rcx, 60
    rep movsb
    mov eax, [raw_termios + 12]
    and eax, ~(ICANON | ECHO | ISIG)
    mov [raw_termios + 12], eax
    mov byte [raw_termios + 17 + VMIN], 1
    mov byte [raw_termios + 17 + VTIME], 0
    mov rax, SYS_IOCTL
    xor edi, edi
    mov esi, TCSETSW
    lea rdx, [raw_termios]
    syscall
    ret

get_term_size:
    push rbx
    push r12

    ; Try ioctl TIOCGWINSZ first (fastest)
    sub rsp, 8
    mov qword [rsp], 0
    mov rax, SYS_IOCTL
    xor edi, edi             ; stdin
    mov esi, TIOCGWINSZ
    lea rdx, [rsp]
    syscall
    test rax, rax
    js .gts_try_stdout
    movzx eax, word [rsp + 2]
    cmp eax, 2
    jge .gts_ioctl_ok
.gts_try_stdout:
    mov rax, SYS_IOCTL
    mov rdi, 1
    mov esi, TIOCGWINSZ
    lea rdx, [rsp]
    syscall
    test rax, rax
    js .gts_try_stderr
    movzx eax, word [rsp + 2]
    cmp eax, 2
    jl .gts_try_stderr
.gts_ioctl_ok:
    movzx eax, word [rsp]
    test eax, eax
    jnz .gts_ioctl_row_ok
    mov eax, 50
.gts_ioctl_row_ok:
    mov [term_rows], rax
    movzx eax, word [rsp + 2]
    mov [term_cols], rax
    add rsp, 8
    pop r12
    pop rbx
    ret

.gts_try_stderr:
    ; Try stderr (fd 2)
    mov rax, SYS_IOCTL
    mov rdi, 2
    mov esi, TIOCGWINSZ
    lea rdx, [rsp]
    syscall
    test rax, rax
    js .gts_defaults
    movzx eax, word [rsp + 2]
    cmp eax, 2
    jge .gts_ioctl_ok
.gts_defaults:
    ; Use sensible defaults
    mov qword [term_rows], 50
    mov qword [term_cols], 80
    add rsp, 8
    pop r12
    pop rbx
    ret

.gts_try_ansi:
    add rsp, 8
    ; ANSI method: save cursor, move to 9999;9999, query position, restore
    ; Save cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.gts_save]
    mov rdx, 2
    syscall
    ; Move to bottom-right
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.gts_move]
    mov rdx, .gts_move_len
    syscall
    ; Query cursor position (terminal responds ESC[row;colR)
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.gts_query]
    mov rdx, 4
    syscall
    ; Read response
    lea rbx, [tmp_buf]
    xor r12d, r12d
.gts_read_resp:
    mov rax, SYS_READ
    xor edi, edi
    lea rsi, [rbx + r12]
    mov rdx, 1
    syscall
    test rax, rax
    jle .gts_ansi_fail
    cmp byte [rbx + r12], 'R'
    je .gts_got_resp
    inc r12
    cmp r12, 30
    jge .gts_ansi_fail
    jmp .gts_read_resp
.gts_got_resp:
    ; Restore cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.gts_restore]
    mov rdx, 2
    syscall
    ; Parse ESC[row;colR from tmp_buf
    ; Skip ESC[
    lea rsi, [tmp_buf + 2]
    ; Parse row
    xor eax, eax
    mov rcx, 10
.gts_parse_row:
    movzx edx, byte [rsi]
    cmp dl, ';'
    je .gts_row_parsed
    sub dl, '0'
    imul rax, rcx
    add rax, rdx
    inc rsi
    jmp .gts_parse_row
.gts_row_parsed:
    mov [term_rows], rax
    inc rsi                  ; skip ';'
    ; Parse col
    xor eax, eax
.gts_parse_col:
    movzx edx, byte [rsi]
    cmp dl, 'R'
    je .gts_col_parsed
    cmp dl, 0
    je .gts_col_parsed
    sub dl, '0'
    imul rax, rcx
    add rax, rdx
    inc rsi
    jmp .gts_parse_col
.gts_col_parsed:
    mov [term_cols], rax
    pop r12
    pop rbx
    ret

.gts_ansi_fail:
    ; Restore cursor
    mov rax, SYS_WRITE
    mov rdi, 1
    lea rsi, [.gts_restore]
    mov rdx, 2
    syscall
    mov qword [term_rows], 50
    mov qword [term_cols], 80
    pop r12
    pop rbx
    ret

.gts_save:    db 27, '7'            ; ESC 7 = save cursor
.gts_restore: db 27, '8'            ; ESC 8 = restore cursor
.gts_move:    db 27, "[9999;9999H"  ; move to bottom-right corner
.gts_move_len equ $ - .gts_move
.gts_query:   db 27, "[6n"          ; query cursor position

; ══════════════════════════════════════════════════════════════════════
; Theme initialization
; ══════════════════════════════════════════════════════════════════════

; Set default theme (monokai)
init_default_theme:
    lea rsi, [theme_data]    ; monokai is first entry
    jmp apply_theme

; Set theme by name. rdi = theme name string
set_theme:
    push rbx
    push r12
    mov r12, rdi
    lea rbx, [theme_names]
    xor ecx, ecx             ; theme index
.st_loop:
    mov rdi, [rbx]
    test rdi, rdi
    jz .st_default            ; not found, use default
    push rcx
    push rbx
    mov rsi, rdi
    mov rdi, r12
    call strcmp
    pop rbx
    pop rcx
    test rax, rax
    jz .st_found
    add rbx, 8
    inc ecx
    jmp .st_loop
.st_found:
    ; Theme index in ecx, each theme is 8 bytes
    imul eax, ecx, 8
    lea rsi, [theme_data + rax]
    pop r12
    pop rbx
    jmp apply_theme
.st_default:
    lea rsi, [theme_data]    ; monokai
    pop r12
    pop rbx
    jmp apply_theme

; Apply theme from data at rsi (8 bytes: kw, str, cmt, num, typ, func, prep, punct)
apply_theme:
    movzx eax, byte [rsi]
    mov [th_keyword], al
    movzx eax, byte [rsi + 1]
    mov [th_string], al
    movzx eax, byte [rsi + 2]
    mov [th_comment], al
    movzx eax, byte [rsi + 3]
    mov [th_number], al
    movzx eax, byte [rsi + 4]
    mov [th_type], al
    movzx eax, byte [rsi + 5]
    mov [th_func], al
    movzx eax, byte [rsi + 6]
    mov [th_preproc], al
    movzx eax, byte [rsi + 7]
    mov [th_punct], al
    ret

; ══════════════════════════════════════════════════════════════════════
; String utilities
; ══════════════════════════════════════════════════════════════════════
strlen:
    push rdi
    xor eax, eax
.sl_loop:
    cmp byte [rdi], 0
    je .sl_done
    inc rdi
    inc eax
    jmp .sl_loop
.sl_done:
    pop rdi
    ret

strcmp:
    push rdi
    push rsi
.sc_loop:
    movzx eax, byte [rdi]
    movzx ecx, byte [rsi]
    cmp al, cl
    jne .sc_diff
    test al, al
    jz .sc_equal
    inc rdi
    inc rsi
    jmp .sc_loop
.sc_diff:
    mov eax, 1
    pop rsi
    pop rdi
    ret
.sc_equal:
    xor eax, eax
    pop rsi
    pop rdi
    ret

strcpy_rsi_rdi:
    xor eax, eax
.scrd_loop:
    mov cl, [rsi]
    mov [rdi], cl
    test cl, cl
    jz .scrd_done
    inc rsi
    inc rdi
    inc eax
    jmp .scrd_loop
.scrd_done:
    ret

itoa:
    push rbx
    push rcx
    mov rbx, rdi
    xor ecx, ecx
    mov r8, 10
.itoa_div:
    xor edx, edx
    div r8
    add dl, '0'
    push rdx
    inc ecx
    test rax, rax
    jnz .itoa_div
    xor eax, eax
.itoa_pop:
    pop rdx
    mov [rbx + rax], dl
    inc eax
    dec ecx
    jnz .itoa_pop
    mov byte [rbx + rax], 0
    pop rcx
    pop rbx
    ret

; Parse "M-N" range string in rax, sets pane_start_line and pane_end_line
parse_range:
    push rbx
    push rdi
    mov rdi, rax
    ; Parse first number
    xor eax, eax
    mov rbx, 10
.pr_first:
    movzx ecx, byte [rdi]
    cmp cl, '-'
    je .pr_dash
    cmp cl, '0'
    jb .pr_dash
    cmp cl, '9'
    ja .pr_dash
    sub cl, '0'
    mul rbx
    add rax, rcx
    inc rdi
    jmp .pr_first
.pr_dash:
    mov [pane_start_line], rax
    cmp byte [rdi], '-'
    jne .pr_done
    inc rdi
    ; Parse second number
    xor eax, eax
.pr_second:
    movzx ecx, byte [rdi]
    cmp cl, '0'
    jb .pr_end
    cmp cl, '9'
    ja .pr_end
    sub cl, '0'
    mul rbx
    add rax, rcx
    inc rdi
    jmp .pr_second
.pr_end:
    mov [pane_end_line], rax
.pr_done:
    pop rdi
    pop rbx
    ret

; Parse integer from null-terminated string in rax
parse_int:
    push rbx
    push rdi
    mov rdi, rax
    xor eax, eax
    mov rbx, 10
.pi_loop:
    movzx ecx, byte [rdi]
    cmp cl, '0'
    jb .pi_done
    cmp cl, '9'
    ja .pi_done
    sub cl, '0'
    mul rbx
    add rax, rcx
    inc rdi
    jmp .pi_loop
.pi_done:
    pop rdi
    pop rbx
    ret

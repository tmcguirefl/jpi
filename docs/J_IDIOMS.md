# J Language Idioms and Lessons Learned

A reference of practical J idioms, patterns, and standard library features discovered during the J-PI agent project. Useful for this and future J projects.

---

## Table of Contents
- [Verb Definition Styles](#verb-definition-styles)
- [Standard Library Verbs](#standard-library-verbs)
- [File I/O](#file-io)
- [String Manipulation](#string-manipulation)
- [Boxing and Unboxing](#boxing-and-unboxing)
- [Table Lookup with i.](#table-lookup-with-i)
- [Agenda Dispatch (@.)](#agenda-dispatch-)
- [Currying Dyads with Bond (&)](#currying-dyads-with-bond-)
- [Shell and Environment Access](#shell-and-environment-access)
- [JSON Handling](#json-handling)
- [Common Pitfalls](#common-pitfalls)

---

## Verb Definition Styles

J provides named constants for readable verb definitions. These are built into the standard profile — do not redefine them.

```j
NB. Monad (one argument, y)
myverb =: monad define
  echo 'got: ' , y
)

NB. Dyad (two arguments, x and y)
myverb =: dyad define
  x + y
)

NB. Verb with both monad and dyad cases
NB. monad above the :, dyad below
myverb =: verb define
  100 myverb y       NB. monad defaults x to 100
:
  x + y              NB. dyad
)
```

The named constants and their values:
| Name | Value | Usage |
|------|-------|-------|
| `monad` | `3` | `monad define` = `3 : 0` |
| `dyad` | `4` | `dyad define` = `4 : 0` |
| `define` | `:0` | used with `monad`/`dyad`/`verb` |

---

## Standard Library Verbs

These are loaded by the standard J profile and available in every session. Do not redefine them.

| Verb | Purpose | Example |
|------|---------|---------|
| `tolower` | Lowercase a string | `tolower 'HELLO'` → `'hello'` |
| `toupper` | Uppercase a string | `toupper 'hello'` → `'HELLO'` |
| `chopstring` | Box words split by whitespace | `chopstring 'run ls please'` → `┌───┬──┬──────┐ │run│ls│please│ └───┴──┴──────┘` |
| `cutopen` | Box words (similar to chopstring) | `cutopen 'a b c'` |
| `fread` | Read entire file as string | `fread 'file.txt'` |
| `freads` | Read file as text (handles CRLF) | `freads 'file.txt'` |
| `fwrite` | Write string to file (binary) | `'data' fwrite 'file.txt'` |
| `fwrites` | Write text to file (handles line endings) | `'data' fwrites 'file.txt'` |
| `fappend` | Append string to file | `'line' fappend 'log.txt'` |
| `ferase` | Delete a file | `ferase 'file.txt'` |
| `fexist` | Check if file exists | `fexist 'file.txt'` |
| `rplc` | String replacement (all occurrences) | `'hello' rplc 'l';'r'` |

---

## File I/O

### Read a file into a boxed list of lines
```j
NB. 'b' option returns each line as a separate box
lines =. 'b' freads 'file.txt'
```

### Read first N lines of a file
```j
NB. {. (take) gets the first N items from the boxed list
first100 =. 100 {. 'b' freads 'file.txt'
```

### Read entire file as a single string
```j
content =. fread 'file.txt'
```

### Write a text file
```j
'Hello World' fwrites 'output.txt'
```

### Append to a file
```j
('log entry' , LF) fappend 'log.txt'
```

---

## String Manipulation

### Split string into boxed words
```j
chopstring 'read file.txt now'
NB. result: 'read';'file.txt';'now'
```

### Extract command and arguments from input
```j
words =. chopstring 'write test.txt hello world'
cmd =. > {. words                              NB. first word unboxed: 'write'
remainder =. _1 }. ; (,&' ') each }. words    NB. rejoin rest: 'test.txt hello world'
```

The remainder idiom explained:
1. `}. words` — drop the first word (the command)
2. `(,&' ') each` — append a space to each remaining boxed word
3. `;` — raze (unbox and join into a single string)
4. `_1 }.` — drop the trailing space

### String replacement
```j
NB. rplc replaces all occurrences; takes pairs of old;new
'hello world' rplc 'world';'J'    NB. → 'hello J'
```

---

## Boxing and Unboxing

### Create a boxed list of strings
```j
NB. Use literal semicolons (preferred style)
actions =. 'read';'run';'edit';'write'
```

### Do NOT use semicolons between groups expecting to stay grouped
```j
NB. WRONG: flattens into 6 items
defs =. ('a';'b';'c') ; ('d';'e';'f')    NB. 6 items!

NB. RIGHT: box each group with < to keep them as units
defs =. (<'a';'b';'c') , (<'d';'e';'f')  NB. 2 items, each a boxed triple
```

### Unbox a single item
```j
> {. actions    NB. 'read' (unboxed string)
```

### Reshape a flat boxed list into a table
```j
NB. _2 ]\ takes items pairwise into a 2-column table
table =. _2 ]\ 'key1';'val1';'key2';'val2'
NB. result: 2x2 boxed table
```

---

## Table Lookup with i.

The `i.` verb uses hashing under the covers for fast lookup. Use it with boxed string lists or tables.

### Simple list lookup
```j
ACTIONS =: 'read';'run';'edit';'write'
idx =. ACTIONS i. < 'run'          NB. result: 1
NB. if not found, idx = #ACTIONS   NB. (one past the end)
```

### 2-column table lookup
```j
NB. Build a key-value lookup table
URLS =: _2 ]\ 'openrouter';'https://openrouter.ai/api/v1/chat/completions';'anthropic';'https://api.anthropic.com/v1/messages'

NB. Find key in column 0, extract value from column 1
idx =. ({."1 URLS) i. <'openrouter'
url =. > (<idx, 1) { URLS
```

---

## Agenda Dispatch (@.)

The agenda conjunction `@.` selects a verb from a gerund based on an index. Combined with `i.` lookup, it replaces `select./case.` blocks.

```j
NB. Define action verbs
read_verb =: monad define
  echo 'Reading: ' , y
)
run_verb =: monad define
  echo 'Running: ' , y
)
unknown_verb =: monad define
  echo 'Unknown: ' , y
)

NB. Boxed action names (order matches the gerund)
ACTIONS =: 'read';'run'

NB. Dispatch: i. finds the index, @. selects the verb
NB. If not found, i. returns #ACTIONS which hits unknown_verb (the last one)
idx =. ACTIONS i. < cmd
(read_verb`run_verb`unknown_verb) @. idx remainder
```

This is cleaner and faster than `select./case.` for string dispatch.

---

## Currying Dyads with Bond (&)

To use a dyad with `each`, bond the left argument with `&`:

```j
NB. mk_tool is a dyad: x mk_tool y
NB. To map it over a list, bond the left argument:
'parameters'&mk_tool each defs
```

This creates a monad `'parameters'&mk_tool` that `each` can apply to every item. General pattern:

```j
x&verb each list    NB. apply (x verb item) to each item in list
```

---

## Shell and Environment Access

### Execute a shell command and capture output
```j
result =. 2!:0 'ls -la'
```

### Read an environment variable
```j
key =. 2!:5 'OPENROUTER_API_KEY'
```

### Foreign conjunction families (m!:n)
| Family | Purpose |
|--------|---------|
| `0!:` | Script loading |
| `1!:` | Low-level file I/O |
| `2!:` | Host/shell commands and environment |
| `3!:` | Type/representation queries |
| `6!:` | Time functions |

---

## JSON Handling

### Load the standard JSON addon
```j
require 'convert/json'
```

### Parse a JSON string into J data
```j
parsed =. dec_json '{"name":"test","value":42}'
```

### Access a key from a parsed JSON object
```j
NB. gethash_json looks up a key in a 2-row boxed matrix
val =. > 'name' gethash_json parsed
```

### Encode J data as JSON
```j
NB. enc_json handles:
NB.   strings → "string"
NB.   numbers → number
NB.   boxed lists → JSON arrays
NB.   2-row boxed matrices → JSON objects (row 0 = keys, row 1 = values)
enc_json ('name';'age') ,: 'Alice'; 30
NB. → '{"name":"Alice","age":30}'
```

### Building JSON strings directly
For complex or nested payloads, building JSON as strings is often more reliable than trying to construct nested boxed structures for `enc_json`:

```j
NB. String concatenation for predictable JSON output
payload =. '{"model":"' , MODEL , '","messages":[{"role":"user","content":"' , msg , '"}]}'
```

### JSON escaping for embedded strings
```j
json_esc =: monad define
  y rplc '\';'\\';'"';'\"';LF;'\n';CR;'\r';TAB;'\t'
)
```

---

## Common Pitfalls

### 1. Implicit verb invocation
J interpreters may not evaluate `verb define ... ) ''` on one logical line. Define the verb first, then call it explicitly on a separate line:
```j
NB. WRONG (may fail in some J interpreters)
API_KEY =: monad define
  ...
) ''

NB. RIGHT
get_api_key =: monad define
  ...
)
API_KEY =: get_api_key ''
```

### 2. Semicolons flatten across groups
```j
NB. WRONG: 6 items
('a';'b';'c') ; ('d';'e';'f')

NB. RIGHT: 2 boxed triples
(<'a';'b';'c') , (<'d';'e';'f')
```

### 3. Control structures only inside explicit definitions
`for.`, `while.`, `if.`, `try.` etc. only work inside `monad define` / `dyad define` blocks, not at the top-level script scope.

### 4. stdin is file number 1, not 2
```j
input =. 1!:1 ] 1    NB. read from keyboard (stdin)
NB. 1 = stdin, 2 = screen (stdout)
```

### 5. Over-comment, don't over-name
J primitives like `i.`, `{.`, `}.`, `E.`, `@.`, `each` are readable to any J programmer. Use comments to explain *what the line does*, not what the verbs mean. Don't wrap single-use expressions in named verbs just for English readability.

```j
NB. WRONG: unnecessary wrapper
get_first =: {.
get_action_index =: ACTIONS&i.@:(tolower)

NB. RIGHT: use the idiom directly, comment what it does
idx =. ACTIONS i. < tolower cmd    NB. look up command in action list
```

---

## Quick Reference Card

```j
NB. Read file into boxed lines     'b' freads 'file.txt'
NB. First 10 lines                 10 {. 'b' freads 'file.txt'
NB. Read file as string            fread 'file.txt'
NB. Write text file                'data' fwrites 'file.txt'
NB. Run shell command              2!:0 'ls'
NB. Get env var                    2!:5 'HOME'
NB. Box words by whitespace        chopstring 'hello world'
NB. Lookup in boxed list           ('a';'b';'c') i. <'b'       NB. → 1
NB. Table from flat list           _2 ]\ 'k1';'v1';'k2';'v2'
NB. Dispatch verb by index         (v1`v2`v3) @. idx y
NB. Curry dyad for each            x&verb each list
NB. Parse JSON                     dec_json '{"a":1}'
NB. Lookup JSON key                > 'key' gethash_json parsed
NB. Timestamp                      6!:0 ''
```

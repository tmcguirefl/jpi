NB. ============================================================
NB. md.ijs — Markdown-to-ANSI renderer for terminal
NB. Ported from TermMark (github.com/ishanawal/TermMark)
NB.
NB. Two-phase: parse lines into tokens, then render tokens
NB. to ANSI escape strings.  Never does global rplc on content.
NB. ============================================================

cocurrent 'md'

NB. -- ANSI escape codes (same as vt.ijs ESC) --
ESC   =: 27{a.
CSI   =: ESC,'['
RESET =: CSI,'0m'
BOLD  =: CSI,'1m'
DIM   =: CSI,'2m'
ITALIC=: CSI,'3m'
ULINE =: CSI,'4m'
CYAN  =: CSI,'36m'
GREEN =: CSI,'32m'
MAGENTA=: CSI,'35m'
BLUE  =: CSI,'34m'
YELLOW=: CSI,'33m'
BRCYAN=: CSI,'96m'
BRYELLOW=: CSI,'93m'
BGDGRAY=: CSI,'100m'
LTGRAY=: CSI,'37m'
DKGRAY=: CSI,'90m'
LF    =: 10{a.
CR    =: 13{a.

NB. ============================================================
NB. INLINE PARSER
NB. Walks a string character by character.
NB. Returns a list of boxed pairs: (<type ; text)
NB.   type: 'plain' 'bold' 'italic' 'bolditalic' 'code' 'link'
NB. ============================================================

NB. parse_until: extract text up to delimiter d starting at position p in string s
NB. returns (text ; new_position)
parse_until =: dyad define
  d =. , > 0 { x
  s =. , > 1 { x
  p =. > 2 { x
  r =. ''
  while. p < #s do.
    if. d -: (#d) {. p }. s do. break. end.
    r =. r , p { s
    p =. p + 1
  end.
  r ; p
)

NB. parse_inline: full inline parser for one line of text
NB. y is a string, returns list of (<type;content) boxes
parse_inline =: monad define
  s =. ,y
  n =. #s
  p =. 0
  tokens =. 0$a:
  plain =. ''
  while. p < n do.
    NB. *** bold italic ***
    if. (p+2 < n) *. '***' -: 3{. p}. s do.
      if. #plain do. tokens =. tokens , < 'plain';plain end.
      plain =. ''
      p =. p + 3
      tmp =. ('***';s;p) parse_until ''
      content =. >0{tmp
      np =. >1{tmp
      if. np+2 < n do. if. '***' -: 3{. np}. s do.
        tokens =. tokens , < 'bolditalic';content
        p =. np + 3
      else.
        plain =. plain , '***' , content
        p =. np
      end. else.
        plain =. plain , '***' , content
        p =. np
      end.
    NB. ** bold **
    elseif. (p+1 < n) *. '**' -: 2{. p}. s do.
      if. #plain do. tokens =. tokens , < 'plain';plain end.
      plain =. ''
      p =. p + 2
      tmp =. ('**';s;p) parse_until ''
      content =. >0{tmp
      np =. >1{tmp
      if. np+1 < n do. if. '**' -: 2{. np}. s do.
        tokens =. tokens , < 'bold';content
        p =. np + 2
      else.
        plain =. plain , '**' , content
        p =. np
      end. else.
        plain =. plain , '**' , content
        p =. np
      end.
    NB. ` code `
    elseif. '`' = p{s do.
      if. #plain do. tokens =. tokens , < 'plain';plain end.
      plain =. ''
      p =. p + 1
      tmp =. ('`';s;p) parse_until ''
      content =. >0{tmp
      np =. >1{tmp
      if. np < n do. if. '`' = np{s do.
        tokens =. tokens , < 'code';content
        p =. np + 1
      else.
        plain =. plain , '`' , content
        p =. np
      end. else.
        plain =. plain , '`' , content
        p =. np
      end.
    NB. * italic * (single, only if not **)
    elseif. '*' = p{s do.
      if. #plain do. tokens =. tokens , < 'plain';plain end.
      plain =. ''
      p =. p + 1
      tmp =. ('*';s;p) parse_until ''
      content =. >0{tmp
      np =. >1{tmp
      if. np < n do. if. '*' = np{s do.
        tokens =. tokens , < 'italic';content
        p =. np + 1
      else.
        plain =. plain , '*' , content
        p =. np
      end. else.
        plain =. plain , '*' , content
        p =. np
      end.
    NB. _ italic _
    elseif. '_' = p{s do.
      if. #plain do. tokens =. tokens , < 'plain';plain end.
      plain =. ''
      p =. p + 1
      tmp =. ('_';s;p) parse_until ''
      content =. >0{tmp
      np =. >1{tmp
      if. np < n do. if. '_' = np{s do.
        tokens =. tokens , < 'italic';content
        p =. np + 1
      else.
        plain =. plain , '_' , content
        p =. np
      end. else.
        plain =. plain , '_' , content
        p =. np
      end.
    NB. default: accumulate plain text
    elseif. do.
      plain =. plain , p{s
      p =. p + 1
    end.
  end.
  if. #plain do. tokens =. tokens , < 'plain';plain end.
  tokens
)

NB. ============================================================
NB. BLOCK PARSER
NB. Splits markdown text into lines, classifies each line.
NB. Returns list of boxed (type ; data) where data varies:
NB.   'heading'   : level ; inline_tokens
NB.   'bullet'    : inline_tokens
NB.   'numbered'  : inline_tokens
NB.   'code'      : lang ; code_lines (list of strings)
NB.   'quote'     : inline_tokens
NB.   'hrule'     : empty
NB.   'paragraph' : inline_tokens
NB.   'blank'     : empty
NB. ============================================================

NB. helper: count leading chars c in string s
count_leading =: dyad define
  s =. y [ c =. x
  n =. 0
  while. n < #s do.
    if. c ~: n{s do. break. end.
    n =. n+1
  end.
  n
)

NB. helper: does string start with pattern?
starts =: dyad define
  if. (#x) > #y do. 0 return. end.
  x -: (#x) {. y
)

NB. ============================================================
NB. TABLE SUPPORT
NB. A markdown table is a header row followed by a separator row
NB. whose cells contain only '-', ':', and spaces, then body rows.
NB. Every row must start with '|'. Rendering measures each cell
NB. in VISIBLE columns (ANSI stripped, UTF-8 aware) and pads so all
NB. pipes align, which the old pass-through never did (misaligned
NB. pipes) while the raw '---' separator row was also printed.
NB. ============================================================

NB. split a table row into cell strings (no leading/trailing pipe).
NB. The leading '|' would yield an empty first segment, so we cut
NB. on ' |' style: simplest is to drop a single leading empty cell.
table_cells =: monad define
  r =. y
  if. '|' = {. r do. r =. }. r end.
  if. (0 < #r) *. ('|' = {: r) do. r =. }: r end.
  NB. cut on '|' keeping all segments
  cells =. <;._2 '|' , r , '|'
  NB. drop the leading empty artifact (before first interior pipe)
  if. (0 < #cells) *. (0 = # > 0 { cells) do. cells =. }. cells end.
  trim1 each cells
)

NB. trim one cell (both ends)
trim1 =: monad define
  r =. lstrip y
  while. (0 < #r) *. ' ' = {: r do. r =. }: r end.
  r
)

NB. is this line a table separator row?  |---|:---:|---:|
table_sep_row =: monad define
  if. '|' ~: {. lstrip y do. 0 return. end.
  cells =. table_cells y
  ok =. 0
  if. 0 < #cells do.
    m =. 0
    for_i. i. #cells do.
      v =. > i { cells
      if. (0 = #v) do. m =. _1 break. end.
      if. -. *./ v e. '- :' do. m =. _1 break. end.
    end.
    if. 0 = m do. ok =. 1 end.
  end.
  ok
)

NB. is this line a table row? (starts with '|', has >= 2 cells)
table_row =: monad define
  if. '|' ~: {. lstrip y do. 0 return. end.
  1 <: # table_cells y
)

NB. parse_inline runs later in render; here we keep RAW cell text
NB. in the token so render_md can measure widths before styling.
NB. token: 'table' ; (header_cells ; body_rows)
NB.   header_cells : boxed list of raw strings
NB.   body_rows   : boxed list of boxed lists of raw strings

NB. helper: strip leading whitespace
lstrip =: monad define
  p =. 0
  while. p < #y do.
    if. -. (p{y) e. ' ',9{a. do. break. end.
    p =. p+1
  end.
  p }. y
)

parse_md =: monad define
  text =. ,y
  NB. isolate thinking tags to their own lines for safe parser extraction
  text =. text rplc '<think>';(LF,'<think>',LF);'</think>';(LF,'</think>',LF)
  text =. text rplc '<thinking>';(LF,'<thinking>',LF);'</thinking>';(LF,'</thinking>',LF)
  text =. text rplc '<thought>';(LF,'<thought>',LF);'</thought>';(LF,'</thought>',LF)

  NB. split into lines on LF
  if. LF ~: {: text do. text =. text , LF end.
  lines =. <;._2 text
  n =. #lines
  i =. 0
  tokens =. 0$a:
  in_code =. 0
  code_lang =. ''
  code_buf =. 0$<''
  in_think =. 0
  think_buf =. 0$<''

  while. i < n do.
    line =. > i{lines
    raw =. line
    stripped =. lstrip line

    NB. thinking block toggle
    if. ('<think>' -: stripped) +. ('<thinking>' -: stripped) +. ('<thought>' -: stripped) do.
      if. in_think do.
        NB. technically malformed if already in it, but close anyway
        tokens =. tokens , < 'think' ; (<think_buf)
      end.
      in_think =. 1
      think_buf =. 0$<''
      i =. i+1
      continue.
    end.

    if. ('</think>' -: stripped) +. ('</thinking>' -: stripped) +. ('</thought>' -: stripped) do.
      if. in_think do.
        tokens =. tokens , < 'think' ; (<think_buf)
        in_think =. 0
      end.
      i =. i+1
      continue.
    end.

    if. in_think do.
      think_buf =. think_buf , < line
      i =. i+1
      continue.
    end.

    NB. code fence toggle
    if. '```' starts line do.
      if. in_code do.
        tokens =. tokens , < 'code' ; code_lang ; (<code_buf)
        in_code =. 0
      else.
        in_code =. 1
        code_lang =. 3 }. line
        code_buf =. 0$<''
      end.
      i =. i+1
      continue.
    end.

    if. in_code do.
      code_buf =. code_buf , < line
      i =. i+1
      continue.
    end.

    NB. blank line
    if. 0 = # lstrip line do.
      tokens =. tokens , < 'blank' ; ''
      i =. i+1
      continue.
    end.

    NB. table: header row | separator row | body rows
    NB. (detected BEFORE hrule: '---' inside '|' is a separator)
    if. table_row line do.
      if. (i + 1) < n do.
        next =. > (i + 1) { lines
        if. table_sep_row next do.
          hdr =. table_cells line
          body =. 0 $ < 0 $ < ''
          j =. i + 2
          while. (j < n) do.
            nxt =. > j { lines
            if. -. table_row nxt do. break. end.
            body =. body , < table_cells nxt
            j =. j + 1
          end.
          tokens =. tokens , < 'table' ; hdr ; (< body)
          i =. j
          continue.
        end.
      end.
    end.

    NB. horizontal rule (--- or ***)
    stripped =. lstrip line
    if. (3 <: #stripped) *. (*./ stripped e. '-*_ ') do.
      if. 1 do.
        tokens =. tokens , < 'hrule' ; ''
        i =. i+1
        continue.
      end.
    end.

    NB. heading: # ## ### etc
    hashes =. '#' count_leading line
    if. (hashes >: 1) *. (hashes <: 6) *. (hashes < #line) do. if. ' ' = hashes { line do.
      content =. (hashes+1) }. line
      tokens =. tokens , < 'heading' ; hashes ; (parse_inline content)
      i =. i+1
      continue.
    end. end.

    NB. blockquote: > text
    if. '> ' starts stripped do.
      content =. 2 }. stripped
      tokens =. tokens , < 'quote' ; (parse_inline content)
      i =. i+1
      continue.
    end.

    NB. unordered list: - item or * item or + item
    if. 2 <: #stripped do.
      if. (({.stripped) e. '-*+') *. ' ' = 1{stripped do.
        content =. 2 }. stripped
        tokens =. tokens , < 'bullet' ; (parse_inline content)
        i =. i+1
        continue.
      end.
    end.

    NB. ordered list: 1. item etc
    dot_pos =. stripped i. '.'
    if. (dot_pos > 0) *. (dot_pos < #stripped) do.
      prefix =. dot_pos {. stripped
      if. (*./ prefix e. '0123456789') do. if. ((dot_pos+1) < #stripped) do. if. ' ' = (dot_pos+1){stripped do.
        content =. (dot_pos+2) }. stripped
        tokens =. tokens , < 'numbered' ; (parse_inline content)
        i =. i+1
        continue.
      end. end. end.
    end.

    NB. paragraph (default)
    tokens =. tokens , < 'paragraph' ; (parse_inline line)
    i =. i+1
  end.

  NB. close unclosed code block
  if. in_code do.
    tokens =. tokens , < 'code' ; code_lang ; (<code_buf)
  end.
  
  NB. close unclosed think block
  if. in_think do.
    tokens =. tokens , < 'think' ; (<think_buf)
  end.

  tokens
)

NB. ============================================================
NB. RENDERER
NB. Walks token list, emits ANSI-styled strings.
NB. Returns a single string with embedded LF.
NB. ============================================================

NB. render inline tokens to ANSI string
render_inline =: monad define
  r =. ''
  for_t. y do.
    tok =. > t
    typ =. > 0 { tok
    content =. > 1 { tok
    select. typ
    case. 'plain' do.
      r =. r , content
    case. 'bold' do.
      r =. r , BOLD , content , RESET
    case. 'italic' do.
      r =. r , ITALIC , content , RESET
    case. 'bolditalic' do.
      r =. r , BOLD , ITALIC , content , RESET
    case. 'code' do.
      r =. r , BGDGRAY , LTGRAY , content , RESET
    end.
  end.
  r
)

NB. UTF-8 helper: encode a unicode codepoint to utf8 bytes
utf8 =: monad define
  if. y < 128 do. y { a. return. end.
  if. y < 2048 do.
    b0 =. 192 + <. y % 64
    b1 =. 128 + 64 | y
    (b0,b1) { a. return.
  end.
  if. y < 65536 do.
    b0 =. 224 + <. y % 4096
    b1 =. 128 + 64 | <. y % 64
    b2 =. 128 + 64 | y
    (b0,b1,b2) { a. return.
  end.
  '?' NB. fallback
)

BULLET =: utf8 16b2022
BOX_H  =: utf8 16b2500   NB. ─
BOX_V  =: utf8 16b2502   NB. │
BOX_TL =: utf8 16b250c   NB. ┌
BOX_BL =: utf8 16b2514   NB. └
NB. repeat a multi-byte string n times: x repstr y
repstr =: dyad define
  ; x # < y
)

NB. render full token list to string with LF separators
render_md =: monad define
  out =. ''
  for_t. y do.
    tok =. > t
    typ =. > {. tok
    dat =. }. tok
    select. typ
    case. 'heading' do.
      level =. > 0 { dat
      itokens =. 1 }. dat
      color =. (level-1) { MAGENTA;GREEN;BLUE;YELLOW;BRCYAN;CYAN
      out =. out , (>color) , BOLD , (render_inline itokens) , RESET , LF , LF
    case. 'paragraph' do.
      out =. out , (render_inline dat) , LF
    case. 'bullet' do.
      out =. out , '  ' , CYAN , BULLET , RESET , ' ' , (render_inline dat) , LF
    case. 'numbered' do.
      out =. out , '  ' , (render_inline dat) , LF
    case. 'quote' do.
      out =. out , BGDGRAY , LTGRAY , '> ' , ITALIC , (render_inline dat) , RESET , LF , LF
    case. 'think' do.
      tlines =. > 0 { dat
      out =. out , DIM , ITALIC , '  (Thinking...)' , RESET , LF
      for_tl. tlines do.
        l =. > tl
        if. 0 < #lstrip l do.
          out =. out , DIM , '  | ' , l , RESET , LF
        else.
          out =. out , LF
        end.
      end.
      out =. out , LF
    case. 'code' do.
      lang =. > 0 { dat
      clines =. > 1 { dat
      hline =. 40 repstr BOX_H
      label =. (BRYELLOW,BOLD,BOX_TL,BOX_H,BOX_H,' ',(>lang),' ',RESET,LF)
      body =. ''
      for_cl. clines do.
        body =. body , BRYELLOW , BOX_V , ' ' , RESET , (>cl) , LF
      end.
      bbar =. BRYELLOW , BOX_BL , hline , RESET , LF
      out =. out , label , body , bbar , LF
    case. 'table' do.
      hdr =. > 0 { dat
      body =. > 1 { dat
      NB. column count from header; short rows padded to it
      nc =. # hdr
      NB. render: header row (bold), then data rows. '|' borders.
      NB. Padding uses VISIBLE width (vis_len on the styled cell)
      NB. so pipes align even when inline styles (**bold**) make
      NB. byte length differ from display cells.
      NB. Widths measured on the STYLED cells, then padded to the
      NB. max per column.
      NB. First pass over header+body styled widths:
      smax =. (#each) hdr
      NB. header styled widths:
      shdr =. 0 $ 0
      for_c. i. nc do.
        shdr =. shdr , (vis_len_base_ render_inline parse_inline > c { hdr)
      end.
      smax =. shdr
      sbody =. 0 $ < 0 $ 0
      for_r. body do.
        cells =. > r
        while. nc > #cells do. cells =. cells , < '' end.
        sw =. 0 $ 0
        for_c. i. nc do.
          sw =. sw , (vis_len_base_ render_inline parse_inline > c { cells)
        end.
        sbody =. sbody , < sw
        for_c. i. nc do.
          wc =. > c { sw
          wm =. > c { smax
          if. wc > wm do.
            smax =. (c {. smax) , wc , ((c + 1) }. smax)
          end.
        end.
      end.
      NB. header row (bold)
      line =. ''
      for_c. i. nc do.
        styled =. render_inline parse_inline > c { hdr
        padn =. (> c { smax) - (vis_len_base_ styled)
        line =. line , '| ' , styled , ((0 >. padn) # ' ') , ' '
      end.
      out =. out , BOLD , line , '|' , RESET , LF
      NB. body rows
      ri =. 0
      for_r. body do.
        cells =. > r
        while. nc > #cells do. cells =. cells , < '' end.
        line =. ''
        for_c. i. nc do.
          styled =. render_inline parse_inline > c { cells
          padn =. (> c { smax) - (vis_len_base_ styled)
          line =. line , '| ' , styled , ((0 >. padn) # ' ') , ' '
        end.
        out =. out , line , '|' , LF
      end.
      out =. out , LF
    case. 'hrule' do.
      out =. out , DKGRAY , (60#'_') , RESET , LF , LF
    case. 'blank' do.
      out =. out , LF
    end.
  end.
  out
)

NB. ============================================================
NB. PUBLIC API:  md_render text
NB. Parses markdown text and returns ANSI-rendered string.
NB. ============================================================
md_render =: monad define
  render_md parse_md y
)

NB. (utf8 defined above)

NB. Agent Skills — discovery, frontmatter parsing, system prompt injection
NB. skills.ijs
NB.
NB. Implements the Agent Skills component of the Agent Plugins v1.0.0 standard
NB. (agent-plugins.org). Skills are SKILL.md files with YAML frontmatter.
NB. The model reads them as instructions — they don't execute code.
NB.
NB. Spec: https://agentskills.io/specification
NB. Each skill is a directory containing SKILL.md with required frontmatter:
NB.   name: skill-name (lowercase, hyphens, max 64 chars)
NB.   description: What the skill does and when to use it (max 1024 chars)
NB.
NB. Discovery locations (fixed per Agent Plugins spec):
NB.   ./skills/*/SKILL.md              — project-local skills
NB.   ~/.jpi/skills/*/SKILL.md         — user-global skills
NB.   <plugin>/skills/*/SKILL.md      — plugin-packaged skills (via plugins.ijs)

require 'files'

NB. ================================================================
NB. Global registry of discovered skills
NB. Each entry: name ; description ; path (absolute path to SKILL.md)
SKILLS =: 0 3 $ <''

NB. ================================================================
NB. Minimal YAML frontmatter parser
NB. Extracts key: value pairs from the frontmatter block (between --- delimiters)
NB. Returns a 2-column table of (key;value) boxed strings, or empty if no frontmatter
parse_frontmatter =: monad define
  lines =. <;._2 y, (LF -. {: y) # LF
  if. 0 = #lines do. 0 2 $ <'' return. end.
  NB. First non-empty line must be ---
  start =. 0
  while. (start < #lines) *. 0 = # > start { lines do. start =. start + 1 end.
  if. start >: #lines do. 0 2 $ <'' return. end.
  if. '-' -.@-: {. > start { lines do. 0 2 $ <'' return. end.
  NB. Find closing ---
  end =. start + 1
  while. (end < #lines) *. '-' -.@-: {. > end { lines do. end =. end + 1 end.
  if. end >: #lines do. 0 2 $ <'' return. end.
  NB. Parse key: value pairs from lines start+1 to end-1
  kv =. 0 2 $ <''
  for_i. (start+1) + i. (end - start - 1) do.
    line =. > i { lines
    if. 0 = #line do. continue. end.
    NB. Skip comment lines
    if. '#' = {. line do. continue. end.
    colon =. line i. ':'
    if. colon >: #line do. continue. end.
    key =. colon {. line
    val =. (colon+1) }. line
    NB. Strip leading/trailing whitespace from key and val
    key =. dblstripp key
    val =. dblstripp val
    kv =. kv , key ; val
  end.
  kv
)

NB. Strip leading and trailing whitespace (spaces, tabs)
dblstripp =: monad define
  ws =. ' ', TAB
  NB. strip leading whitespace
  while. (0 < #y) *. ws e.~ {. y do. y =. }. y end.
  NB. strip trailing whitespace
  while. (0 < #y) *. ws e.~ {: y do. y =. }: y end.
  y
)

NB. ================================================================
NB. Get a value from a frontmatter table by key
NB. x = key string, y = kv table (from parse_frontmatter)
get_fm_value =: dyad define
  if. 0 = {. $ y do. '' return. end.
  idx =. (0 {"1 y) i. < x
  if. idx >: {. $ y do. '' return. end.
  > (< idx, 1) { y
)

NB. ================================================================
NB. Load and validate a single SKILL.md file
NB. y = absolute path to SKILL.md
NB. Returns: name ; description ; path  (boxed), or empty if invalid
load_skill =: monad define
  if. -. fexist y do. '' return. end.
  content =. fread y
  if. 0 = #content do. '' return. end.
  fm =. parse_frontmatter content
  if. 0 = {. $ fm do. '' return. end.
  name =. 'name' get_fm_value fm
  desc =. 'description' get_fm_value fm
  if. (0 = #name) +. (0 = #desc) do. '' return. end.
  name ; desc ; y
)

NB. ================================================================
NB. Discover skills in a directory's skills/ subfolder
NB. y = base directory path (e.g. '.', '~/.jpi', or a plugin root)
NB. Adds valid skills to the global SKILLS table
discover_skills_in =: monad define
  skills_dir =. y , '/skills'
  if. -. fexist skills_dir do. return. end.
  NB. List immediate child directories of skills/
  try.
    entries =. 2!:0 'ls -d ' , skills_dir , '/*/ 2>/dev/null'
    if. 0 = #entries do. return. end.
    dirs =. <;._2 entries , (LF -. {: entries) # LF
    for_d. dirs do.
      dir =. > d
      NB. Remove trailing slash if present
      if. '/' = {: dir do. dir =. }: dir end.
      skill_file =. dir , '/SKILL.md'
      if. fexist skill_file do.
        result =. load_skill skill_file
        if. 0 < #result do.
          SKILLS =: SKILLS , result
        else.
          echo 'SKILLS: skipping invalid skill: ' , skill_file
        end.
      end.
    end.
  catch.
    echo 'SKILLS: error discovering in ' , skills_dir
  end.
)

NB. ================================================================
NB. Discover all skills from all locations
NB. Called at load time and can be re-called to refresh
discover_all_skills =: monad define
  SKILLS =: 0 3 $ <''
  NB. Project-local skills
  discover_skills_in '.'
  NB. User-global skills
  home =. 2!:5 'HOME'
  if. 0 < #home do.
    discover_skills_in home , '/.jpi'
  end.
  NB. Plugin-packaged skills are discovered by plugins.ijs
  NB. which calls discover_skills_in for each plugin root.
  echo 'Skills loaded: ' , (": {. $ SKILLS) , ' skill(s)'
)

NB. ================================================================
NB. Get skill descriptions for system prompt injection
NB. Returns a string like:
NB.   deploy (How to deploy the service), test (How to run tests)
NB. Returns empty string if no skills
get_skill_descriptions =: monad define
  if. 0 = # SKILLS do. '' return. end.
  parts =. 0 $ <''
  for_i. i. # SKILLS do.
    name =. > (< i, 0) { SKILLS
    desc =. > (< i, 1) { SKILLS
    parts =. parts , < (name , ' (' , ((100 <. #desc) {. desc) , ')')
  end.
  ; parts ,each <', '
)

NB. ================================================================
NB. Get full skill list with paths (for /skills command)
NB. Returns multi-line string
list_skills =: monad define
  if. 0 = # SKILLS do. 'No skills found.' return. end.
  lines =. 0 $ <''
  for_i. i. # SKILLS do.
    name =. > (< i, 0) { SKILLS
    desc =. > (< i, 1) { SKILLS
    path =. > (< i, 2) { SKILLS
    lines =. lines , < (name , '  -  ' , ((80 <. #desc) {. desc) , '  [' , path , ']')
  end.
  ; lines ,each <LF
)

echo 'skills loaded.'

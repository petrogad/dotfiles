#!/usr/bin/env python3
"""Stream notable events from a running Claude Code session (main transcript + subagents).

  session-watch.py <session-id|latest|path.jsonl> [--from-now] [--dir REPO_DIR] [--project-dir DIR] [--interval S]

`latest` is the session most recently STARTED from --dir (default: the current directory), so a
watcher launched from another session in the same directory does not pick itself. The repo's stack
skill (any `*-local-stack` skill in the repo or ~/.claude/skills) is found from the session's cwd.

One line per event: skill loads, agent spawns, first graph lookup per agent, stack commands, questions
to the user, PRs, the user's own messages, and a graph-vs-grep tally every 5 minutes when it changed.
Used to watch an orchestration live; session-audit.py does the full report afterwards.
"""
import glob, json, os, re, sys, time

args = sys.argv[1:]
PROJECTS = os.path.expanduser('~/.claude/projects')
interval = 15
start_dir = os.path.abspath(args[args.index('--dir') + 1]) if '--dir' in args else os.getcwd()
pdir = os.path.join(PROJECTS, re.sub(r'[^A-Za-z0-9]', '-', start_dir))
if '--project-dir' in args: pdir = args[args.index('--project-dir') + 1]
sid = args[0]
if sid.endswith('.jsonl'):
    pdir, sid = os.path.dirname(os.path.abspath(sid)), os.path.basename(sid)[:-6]
elif sid == 'latest':
    found = glob.glob(os.path.join(pdir, '*.jsonl'))
    if not found:
        sys.exit(f'no sessions in {pdir}')
    born = lambda f: getattr(os.stat(f), 'st_birthtime', os.path.getctime(f))
    sid = os.path.basename(max(found, key=born))[:-6]
else:
    hits = glob.glob(os.path.join(PROJECTS, '*', sid + '.jsonl'))
    if not hits:
        sys.exit(f'session {sid} not found under {PROJECTS}')
    pdir = os.path.dirname(hits[0])
print(f'watching {sid} in {pdir}', flush=True)
if '--interval' in args: interval = int(args[args.index('--interval') + 1])

GRAPH = ('search_graph', 'trace_path', 'get_code_snippet', 'query_graph', 'get_architecture',
         'search_code', 'get_file_outline', 'detect_changes')
offsets, seen_ids, first_graph, stack_noted, first_hint = {}, set(), set(), set(), set()
skills = {}  # agent -> set of skills
tally = {'graph': 0, 'grep': 0}
last_tally, last_tally_t = None, time.time()


quiet = '--from-now' in args  # replay history silently, then report only new events
node_noted, stack_read = set(), set()
stack = ''  # the repo's *-local-stack skill name; '' until the session's cwd is seen, None when absent


def find_stack(cwd):
    repo = os.path.join(cwd, 'main') if os.path.isdir(os.path.join(cwd, 'main')) else cwd
    for d in (os.path.join(repo, '.claude', 'skills'), os.path.join(repo, '.agents', 'skills'),
              os.path.expanduser('~/.claude/skills')):
        hits = sorted(glob.glob(os.path.join(d, '*-local-stack')))
        if hits:
            return os.path.basename(hits[0])
    return None


def stack_state(who):
    if not stack:
        return 'no stack skill in repo'
    if stack in skills.get(who, set()) | skills.get('main', set()):
        return f'{stack} loaded: yes'
    return f"{stack} loaded: {'read' if who in stack_read else 'NO'}"


def say(msg):
    if quiet:
        return
    print(time.strftime('%H:%M:%S'), msg, flush=True)


def files():
    main = os.path.join(pdir, sid + '.jsonl')
    return [main] + sorted(glob.glob(os.path.join(pdir, sid, 'subagents', 'agent-*.jsonl')))


def agent_name(path):
    if path.endswith(sid + '.jsonl'):
        return 'main'
    meta = path[:-6] + '.meta.json'
    try:
        m = json.load(open(meta))
        return (m.get('description') or m.get('agentType') or os.path.basename(path))[:40]
    except (OSError, ValueError):
        return os.path.basename(path)[6:14]


ctx = {}  # agent -> [turns, current context, message ids]


def handle(path, o):
    global stack
    who = agent_name(path)
    if stack == '' and o.get('cwd'):
        stack = find_stack(o['cwd'])
    m = o.get('message') or {}
    if o.get('type') == 'assistant' and m.get('usage'):
        st = ctx.setdefault(who, [0, 0, set()])
        if m.get('id') not in st[2]:
            st[2].add(m.get('id'))
            u = m['usage']
            st[0] += 1
            prev, st[1] = st[1], sum(u.get(k) or 0 for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens'))
            for mark in (150_000, 250_000):
                if prev < mark <= st[1]:
                    say(f'[{who}] context passed {mark // 1000}k at turn {st[0]}')
    content = m.get('content')
    if o.get('type') == 'user' and who == 'main' and isinstance(content, str) and not content.startswith('<'):
        say(f'USER: {content[:160]!r}')
    blob = json.dumps(o.get('attachment') or o.get('hookAdditionalContext') or '')
    if 'graph symbol(s) match' in blob:
        tally['hints'] = tally.get('hints', 0) + 1
        if who not in first_hint:
            first_hint.add(who)
            say(f'[{who}] first graph hint received')
    if not isinstance(content, list):
        return
    for c in content:
        if c.get('type') == 'tool_result' and who not in node_noted:
            text = json.dumps(c.get('content'))
            if re.search(r'name: [\w-]+\\ndescription: ', text):
                continue  # a skill file was printed; its own text quotes the error
            if re.search(r'(node|npx|npm|tsc|vitest|nvm)[^\n"]{0,20}: (command )?not found|command not found: (node|npx|npm|tsc|vitest)', text):
                node_noted.add(who)
                say(f'[{who}] node tooling not found; {stack_state(who)}')
        if c.get('type') != 'tool_use' or c.get('id') in seen_ids:
            continue
        seen_ids.add(c.get('id'))
        name, i = c['name'], c.get('input') or {}
        if name == 'Bash' and stack and f'{stack}/SKILL.md' in i.get('command', ''):
            stack_read.add(who)
        if name == 'Skill':
            sk = i.get('skill', '')
            if sk not in skills.setdefault(who, set()):
                skills[who].add(sk)
                say(f'[{who}] loaded skill {sk}')
        elif name in ('Agent', 'Task'):
            say(f"[{who}] spawned {i.get('subagent_type') or 'general'} ({i.get('model') or 'inherit'}): {i.get('description', '')}")
        elif name.startswith('mcp__codebase-memory-mcp__') and name.split('__')[-1] in GRAPH:
            tally['graph'] += 1
            if who not in first_graph:
                first_graph.add(who)
                say(f'[{who}] first graph lookup: {name.split("__")[-1]}')
        elif name in ('Grep', 'Glob', 'Read'):
            tally['grep'] += 1
        elif name == 'Bash':
            cmd = i.get('command', '')
            if any(w in cmd for w in ('grep ', 'rg ', 'sed -n', 'cat ', 'find ')):
                tally['grep'] += 1
            key = (who, 'stack')
            if key not in stack_noted and any(w in cmd for w in ('make up', 'make restart', 'docker compose', 'make acceptance')):
                stack_noted.add(key)
                say(f'[{who}] first stack command; {stack_state(who)}')
            if 'gh pr create' in cmd or 'gh pr merge' in cmd:
                say(f'[{who}] {"PR created" if "create" in cmd else "PR merge"}')
        elif name == 'AskUserQuestion':
            qs = [q.get('header', '') for q in i.get('questions', [])]
            say(f'[{who}] asking the user: {", ".join(qs)}')


while True:
    for f in files():
        try:
            with open(f) as fh:
                fh.seek(offsets.get(f, 0))
                for line in fh:
                    if not line.endswith('\n'):
                        break
                    offsets[f] = offsets.get(f, 0) + len(line.encode())
                    try:
                        handle(f, json.loads(line))
                    except ValueError:
                        pass
        except OSError:
            pass
    quiet = False
    now = time.time()
    if now - last_tally_t >= 300:
        cur = (tally['graph'], tally['grep'], tally.get('hints', 0))
        if cur != last_tally:
            main = ctx.get('main', [0, 0])
            say(f'tally: graph {cur[0]} / grep+read {cur[1]} / hints {cur[2]} / main turns {main[0]}, context {main[1] // 1000}k')
            last_tally = cur
        last_tally_t = now
    time.sleep(interval)

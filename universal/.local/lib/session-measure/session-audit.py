#!/usr/bin/env python3
"""After-action audit of a Claude Code session and its subagents.

What it answers, per orchestration session:
  1. Which skills were invoked, and which skills' triggers fired but were never loaded
     (trigger rules live in session-audit-triggers.json next to this script; grow them).
  2. Per agent (main + every subagent): model, tool calls, tokens processed, codebase-memory
     graph calls vs grep/read-style calls, and whether a hook told it "no indexed project".
  3. Which of the repo's own help files (docs/agents/*.md, repo skills, CLAUDE.md) were read.

Usage:
  session-audit.py <session-id | path/to/session.jsonl | latest> [--project-dir DIR] [--log]

  latest         newest session in --project-dir (default: the dir for $PWD under ~/.claude/projects)
  --repo PATH    repo checkout whose docs/agents and skills count as "the repo's help"
                 (default: the session's first cwd, then ~/dev/<name>/main)
  --log          also append the report to $AGENT_WORK_DIR/artifacts/session-audit-log.md

The transcript
format is internal to Claude Code and can change: the parser skips what it does not recognise.
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECTS = os.path.expanduser('~/.claude/projects')
GRAPH_PREFIX = 'mcp__codebase-memory-mcp__'
# Lookups only: listing, indexing and deleting projects is housekeeping, not use of the graph.
GRAPH_LOOKUPS = {'search_graph', 'trace_path', 'get_code_snippet', 'query_graph', 'get_architecture', 'search_code', 'get_file_outline', 'detect_changes'}
SEARCHY_BASH = re.compile(r'(^|[|;&\s])(grep|rg|find|sed -n|cat|head|tail|awk)\b')
NO_INDEX = re.compile(r'no indexed graph project matched', re.I)
INDEX_CHECK = re.compile(r'\[index-check\] Graph project for this session')
# A search for where code is defined or used: a camelCase/PascalCase identifier, or a declaration.
# Literals, SQL columns, config keys and docs are grep's job and are not counted.
SYMBOL = re.compile(r'\b(export (default )?(async )?(function|const|class|interface|type)\b|[a-z]+[A-Z]\w{2,}|[A-Z][a-z]+[A-Z]\w+)')
SEARCH_SEG = re.compile(r'(?:^|&&|\|\||;|\n)\s*(?:grep|egrep|rg)\s[^|;&\n]*')
GRAPH_HINT = re.compile(r'graph symbol\(s\) match')


def project_dir_for(path):
    return os.path.join(PROJECTS, re.sub(r'[^A-Za-z0-9]', '-', path))


def resolve_session(arg, project_dir):
    if arg.endswith('.jsonl') and os.path.exists(arg):
        return arg
    if arg == 'latest':
        files = sorted(glob.glob(os.path.join(project_dir, '*.jsonl')),
                       key=lambda f: getattr(os.stat(f), 'st_birthtime', os.path.getctime(f)))  # newest STARTED
        if not files:
            sys.exit(f'no sessions in {project_dir}')
        return files[-1]
    hits = glob.glob(os.path.join(PROJECTS, '*', arg + '.jsonl'))
    if not hits:
        sys.exit(f'session {arg} not found under {PROJECTS}')
    return hits[0]


def records(path):
    with open(path, errors='replace') as fh:
        for line in fh:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def tool_uses(rec):
    msg = rec.get('message')
    if rec.get('type') != 'assistant' or not isinstance(msg, dict):
        return []
    content = msg.get('content')
    return [c for c in content if isinstance(c, dict) and c.get('type') == 'tool_use'] if isinstance(content, list) else []


def user_text(rec):
    if rec.get('type') != 'user' or rec.get('isMeta'):
        return ''
    content = (rec.get('message') or {}).get('content')
    if isinstance(content, str):
        # Task notifications and system reminders arrive as user turns; they are not the human.
        return '' if content.lstrip().startswith('<') else content
    if isinstance(content, list):
        return ' '.join(c.get('text', '') for c in content if isinstance(c, dict) and c.get('type') == 'text')
    return ''


def analyse(path):
    a = {
        'models': Counter(), 'tools': Counter(), 'skills': [], 'agents': [], 'tokens': 0, 'out': 0,
        'graph': 0, 'searchy': 0, 'reads': [], 'inputs': [], 'prompts': [], 'no_index_hint': False, 'index_check': False,
        'cwd': None, 'events': [], 'symbol_grep': 0, 'symbol_graph': 0, 'hints': 0, 'turns': 0, 'peak': 0, 'msg_ids': set(), 'billed': 0.0,
    }
    for rec in records(path):
        a['cwd'] = a['cwd'] or rec.get('cwd')
        blob = json.dumps(rec.get('attachment') or rec.get('hookAdditionalContext') or '')
        if NO_INDEX.search(blob):
            a['no_index_hint'] = True
        if INDEX_CHECK.search(blob):
            a['index_check'] = True
        a['hints'] += len(GRAPH_HINT.findall(blob))
        text = user_text(rec)
        if text:
            a['prompts'].append(text)
            a['events'].append(('prompt', text))
        msg = rec.get('message')
        if rec.get('type') == 'assistant' and isinstance(msg, dict):
            if msg.get('model'):
                a['models'][msg['model']] += 1
            u = msg.get('usage') or {}
            # One API response is written as several records (thinking, text, each tool call), each
            # repeating its usage: count a message id once.
            if msg.get('id') not in a['msg_ids']:
                a['msg_ids'].add(msg.get('id'))
                a['turns'] += 1
                ctx = sum(u.get(k) or 0 for k in ('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens'))
                a['peak'] = max(a['peak'], ctx)
                a['tokens'] += ctx + (u.get('output_tokens') or 0)
                # Billed weight in fresh-input-token equivalents, from Anthropic's price ratios:
                # cache read 0.1x, cache write 1.25x, output 5x input. Comparable across sessions
                # without knowing the model's price.
                a['billed'] += ((u.get('input_tokens') or 0) + 1.25 * (u.get('cache_creation_input_tokens') or 0)
                                + 0.1 * (u.get('cache_read_input_tokens') or 0) + 5 * (u.get('output_tokens') or 0))
                a['out'] += u.get('output_tokens') or 0
        for t in tool_uses(rec):
            name, inp = t.get('name', '?'), t.get('input') or {}
            a['tools'][name] += 1
            a['inputs'].append(name + ' ' + json.dumps(inp)[:2000])
            a['events'].append(('tool', name, json.dumps(inp)[:300] if name not in ('Write', 'Edit') else 'writes ' + str(inp.get('file_path', '')),
                                inp.get('skill', '') if name == 'Skill' else '',
                                (inp.get('file_path', '') if name == 'Read' else inp.get('command', '') if name == 'Bash' else '')))
            if name.startswith(GRAPH_PREFIX):
                if name[len(GRAPH_PREFIX):] in GRAPH_LOOKUPS:
                    a['graph'] += 1
                    if name[len(GRAPH_PREFIX):] in ('search_graph', 'trace_path', 'get_code_snippet', 'query_graph'):
                        a['symbol_graph'] += 1
            elif name in ('Grep', 'Glob', 'Read') or (name == 'Bash' and SEARCHY_BASH.search(inp.get('command', ''))):
                a['searchy'] += 1
            searches = [inp.get('pattern', '')] if name == 'Grep' else SEARCH_SEG.findall(inp.get('command', '')) if name == 'Bash' else []
            if any(SYMBOL.search(x) for x in searches):
                a['symbol_grep'] += 1
            if name == 'Skill':
                a['skills'].append(inp.get('skill'))
            if name == 'Agent':
                a['agents'].append((inp.get('subagent_type') or 'general-purpose', inp.get('model') or 'inherit', inp.get('description', '')))
            if name == 'Read':
                a['reads'].append(inp.get('file_path', ''))
            if name == 'Bash':
                a['reads'].append(inp.get('command', ''))
    return a


def repo_help(repo):
    if not repo or not os.path.isdir(repo):
        return []
    found = glob.glob(os.path.join(repo, 'docs/agents/*.md'))
    for d in ('.claude/skills', '.agents/skills'):
        found += glob.glob(os.path.join(repo, d, '*/SKILL.md'))
    for f in ('CLAUDE.md', 'AGENTS.md'):
        if os.path.exists(os.path.join(repo, f)):
            found.append(os.path.join(repo, f))
    seen, out = set(), []
    for f in found:
        rel = os.path.relpath(os.path.realpath(f), os.path.realpath(repo))
        if rel not in seen:
            seen.add(rel)
            out.append(rel)
    return sorted(out)


def guess_repo(cwd):
    if not cwd:
        return None
    if os.path.isdir(os.path.join(cwd, 'docs')) or os.path.exists(os.path.join(cwd, 'CLAUDE.md')) and os.path.isdir(os.path.join(cwd, '.git')):
        return cwd
    main = os.path.join(cwd, 'main')
    return main if os.path.isdir(main) else cwd


def first_trigger(rule, a, is_main):
    """Position of the first event in this agent that fires the rule, with the reason, or None."""
    spawned = 0
    for i, ev in enumerate(a['events']):
        if ev[0] == 'prompt' and is_main and rule.get('prompt_regex') and re.search(rule['prompt_regex'], ev[1], re.I):
            # The skill is due before the first real action after the prompt, not before the prompt.
            nxt = next((j for j in range(i + 1, len(a['events'])) if a['events'][j][0] == 'tool' and a['events'][j][1] not in ('Skill', 'ToolSearch')), i)
            return nxt, 'prompt matched /' + rule['prompt_regex'] + '/'
        if ev[0] != 'tool':
            continue
        if ev[1] == 'Agent':
            spawned += 1
            if is_main and rule.get('agents_spawned_gte') and spawned >= rule['agents_spawned_gte']:
                return i, f'spawned agent #{spawned}'
        if rule.get('tool_input_regex') and re.search(rule['tool_input_regex'], ev[1] + ' ' + ev[2], re.I):
            return i, 'tool call matched /' + rule['tool_input_regex'] + '/'
    return None


def first_load(skill, a):
    for i, ev in enumerate(a['events']):
        if ev[0] == 'tool' and (ev[3] == skill or ev[3].endswith(':' + skill) or f'skills/{skill}/SKILL.md' in ev[4]):
            return i
    return None


def check_triggers(rules, main, subs):
    """A skill counts as used only if this agent loaded it BEFORE the trigger first fired."""
    rows = []
    for label, a, is_main in [('main', main, True)] + [(d[:40], x, False) for d, x in subs]:
        earliest = {}
        for r in rules:
            hit = first_trigger(r, a, is_main)
            if hit and (r['skill'] not in earliest or hit[0] < earliest[r['skill']][0]):
                earliest[r['skill']] = hit
        for skill, (at, why) in earliest.items():
            aliases = [n for rule in rules if rule['skill'] == skill for n in rule.get('aliases', [])]
            r = {'skill': skill}
            hits = [x for x in (first_load(n, a) for n in [skill] + aliases) if x is not None]
            loaded = min(hits) if hits else None
            result = 'loaded first' if loaded is not None and loaded <= at else ('loaded late' if loaded is not None else 'MISSED')
            rows.append((label, r['skill'], result, why))
    invoked = {s for x in [main] + [y for _, y in subs] for s in x['skills'] if s}
    return rows, invoked


def fmt_agent(label, a):
    model = ', '.join(m.replace('claude-', '') for m in a['models']) or '?'
    calls = sum(a['tools'].values())
    ratio = f"{a['graph']}/{a['searchy']}"
    symbols = f"{a['symbol_graph']}/{a['symbol_grep']}"
    # cbm-index-check (dotfiles #42) names the project; the binary's own "no index" line still appears.
    hint = 'project named' if a['index_check'] else ('no index' if a['no_index_hint'] else '')
    return f"| {label} | {model} | {calls} | {a['turns']} | {a['peak'] / 1000:,.0f}k | {a['tokens'] / 1000:,.0f}k | {a['billed'] / 1e6:,.2f}M | {a['out'] / 1000:,.1f}k | {ratio} | {symbols} | {a['hints']} | {hint} |"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('session')
    ap.add_argument('--project-dir', default=project_dir_for(os.getcwd()))
    ap.add_argument('--repo')
    ap.add_argument('--log', action='store_true')
    args = ap.parse_args()

    path = resolve_session(args.session, args.project_dir)
    sid = os.path.basename(path)[:-6]
    main_a = analyse(path)
    subs = []
    for f in sorted(glob.glob(os.path.join(path[:-6], 'subagents', 'agent-*.jsonl'))):
        meta = {}
        try:
            meta = json.load(open(f[:-6] + '.meta.json'))
        except (OSError, ValueError):
            pass
        subs.append((meta.get('description') or os.path.basename(f), analyse(f)))
    repo = args.repo or guess_repo(main_a['cwd'])
    rules = json.load(open(os.path.join(HERE, 'session-audit-triggers.json')))
    # "*-local-stack" stands for the repo's own stack skill, if it has one.
    stack = next((os.path.basename(h) for d in ('.claude/skills', '.agents/skills')
                  for h in sorted(glob.glob(os.path.join(repo or '', d, '*-local-stack')))), None)
    rules = [dict(r, skill=stack) if r['skill'] == '*-local-stack' else r
             for r in rules if r['skill'] != '*-local-stack' or stack]
    trig, invoked = check_triggers(rules, main_a, subs)

    helpfiles = repo_help(repo)
    all_reads = '\n'.join(r for x in [main_a] + [s for _, s in subs] for r in x['reads'])
    all_skills = ' '.join(invoked)

    out = [f"## Session {sid}", '', f"Audited {datetime.date.today()}; transcript `{path}`; repo `{repo}`.", '']
    out += ['### Agents', '', '| Agent | Model | Tool calls | Turns | Peak context | Tokens processed | Billed (input-eq) | Output | Graph / grep-read | Symbol lookups graph / grep | Graph hints received | Start hint |', '|---|---|---|---|---|---|---|---|---|---|---|---|']
    out.append(fmt_agent('main', main_a))
    for desc, a in subs:
        out.append(fmt_agent(desc[:40], a))
    total = main_a['tokens'] + sum(a['tokens'] for _, a in subs)
    billed = main_a['billed'] + sum(a['billed'] for _, a in subs)
    out += ['', f"Billed weight: {billed / 1e6:.2f}M input-token equivalents (main {main_a['billed'] / 1e6:.2f}M). Multiply by the model's input price per million for dollars."]
    out += [f"Main session {main_a['tokens'] / 1e6:.1f}M ({main_a['tokens'] / max(total, 1):.0%}), workers {(total - main_a['tokens']) / 1e6:.1f}M.", f"Total processed: {total / 1e6:.2f}M tokens across {1 + len(subs)} agents (cache reads count, so this overstates cost; compare sessions with each other).", '']
    out += ['### Skills', '', 'Invoked: ' + (', '.join(sorted(invoked)) or 'none'), '']
    if trig:
        out += ['| Agent | Skill | Result | First trigger |', '|---|---|---|---|'] + [f'| {g} | {s} | {r} | {w} |' for g, s, r, w in trig]
    else:
        out.append('No trigger rule fired.')
    out += ['', '### Repo help', '']
    if helpfiles:
        used = [h for h in helpfiles if h in all_reads or h.replace('.agents/skills/', '.claude/skills/') in all_reads or os.path.basename(os.path.dirname(h)) in all_skills]
        unused = [h for h in helpfiles if h not in used]
        out.append(f"Read {len(used)} of {len(helpfiles)}: " + (', '.join(f'`{h}`' for h in used) or 'none'))
        out.append('')
        out.append('Not read (only a gap if the session touched that area): ' + ', '.join(f'`{h}`' for h in unused))
    else:
        out.append('No repo help files found.')
    report = '\n'.join(out) + '\n'
    print(report)
    if args.log:
        work = os.environ.get('AGENT_WORK_DIR') or os.path.expanduser('~/agents')
        os.makedirs(os.path.join(work, 'artifacts'), exist_ok=True)
        with open(os.path.join(work, 'artifacts', 'session-audit-log.md'), 'a') as fh:
            fh.write(report + '\n')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Status line: model|branch|duration on line 1, usage bars on line 2"""
import json, sys, subprocess

data = json.load(sys.stdin)

BLOCKS = ' ▏▎▍▌▋▊▉█'
R = '\033[0m'
DIM = '\033[2m'

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g,0)};60m'

def bar(pct, width=10):
    pct = min(max(pct, 0), 100)
    filled = pct * width / 100
    full = int(filled)
    frac = int((filled - full) * 8)
    b = '█' * full
    if full < width:
        b += BLOCKS[frac]
        b += '░' * (width - full - 1)
    return b

def fmt(label, pct):
    p = round(pct)
    return f'{label} {gradient(pct)}{bar(pct)} {p}%{R}'

def get_git_branch():
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except Exception:
        pass
    return None

def fmt_duration(ms):
    if ms is None:
        return None
    s = int(ms / 1000)
    h, s = divmod(s, 3600)
    m, s = divmod(s, 60)
    if h > 0:
        return f'{h}h{m:02d}m'
    elif m > 0:
        return f'{m}m{s:02d}s'
    else:
        return f'{s}s'

lines = []

# usage bars

bars = []
ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    bars.append(fmt('ctx', ctx))

five = data.get('rate_limits', {}).get('five_hour', {}).get('used_percentage')
if five is not None:
    bars.append(fmt('5h', five))

week = data.get('rate_limits', {}).get('seven_day', {}).get('used_percentage')
if week is not None:
    bars.append(fmt('7d', week))

if bars:
    lines.append(f'{DIM}│{R}'.join(f' {b} ' for b in bars))

# model | branch | duration
model = data.get('model', {}).get('display_name', 'Claude')
branch = get_git_branch()
duration_ms = data.get('cost', {}).get('total_duration_ms')
duration = fmt_duration(duration_ms)

parts = [model]
if branch:
    parts.append(f'🌿 {branch}')
if duration:
    parts.append(f'🕐 {duration}')

info = f' {DIM}│{R} '.join(parts)

lines.append(info)

print('\n'.join(lines), end='')

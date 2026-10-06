"""SSH の実ペインで、成立する機能と再現した問題を別々に集計する。"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'ssh-results' / 'live'
records = json.loads((OUT / 'summary.json').read_text(encoding='utf-8'))
by_id = {r['id']: r for r in records}
checks, defects = [], []

def check(name, condition):
    checks.append({'name': name, 'confirmed': bool(condition)})

def defect(name, observed, evidence):
    defects.append({'name': name, 'observed': bool(observed), 'evidence': evidence})

def probe_ok(r):
    return bool(r.get('prompt_probe_line', '').strip()) and (
        r['prompt_probe_line'].strip() == r.get('prompt_probe_expected', '').strip()) and (
        r['prompt_target_row'] < r['dimensions']['physical_top'])

def input_contains(r, text):
    return any(z['semantic_type'] == 'Input' and text in t
        for z, t in zip(r['zones'], r['zone_texts']))

for label in ['worktree-bash', 'worktree-native']:
    output = by_id[label + '-output']
    marker = 'REMOTE_' + label.upper().replace('-', '_') + '_OUTPUT'
    check(label + ': remote の出力だけをコピー', output['copied'] == marker)
    check(label + ': remote の入力範囲', input_contains(output, marker))
    check(label + ': remote のホスト付き cwd', output['cwd'].startswith('file://kawasaki-pi/'))
    check(label + ': 本番タブ関数のホスト表示', 'kawasaki-pi:almalinux' in output['formatted_tab'])
    check(label + ': 実行中も ssh と判定', by_id[label + '-running']['running_program'] == 'ssh')
    check(label + ': false の保存コード1', '__SSH_STATE__ status=1 pipeline=1' in by_id[label + '-failure-state']['pane_text'])
    check(label + ': パイプ個別 status 1 0', '__SSH_STATE__ status=0 pipeline=1 0' in by_id[label + '-pipeline-state']['pane_text'])
    notification = by_id[label + '-notification']['vars'].get('wezterm_cmd_done', '')
    check(label + ': remote 失敗の通知データ', notification.startswith('1\t') and notification.endswith('\tsleep 2.2; false'))
    lines = '\n'.join('SSH_LINE_' + str(i) for i in range(1, 71))
    check(label + ': 70行を正確にコピー', by_id[label + '-jump']['copied'] == lines)
    check(label + ': remote プロンプトへのジャンプ', probe_ok(by_id[label + '-jump']))
    check(label + ': 空 Enter で直前出力を保持', by_id[label + '-empty-enter']['copied'] == lines)

check('Git Bash: remote Linux がローカル ssh 値を保持', by_id['worktree-bash-running']['vars'].get('WEZTERM_PROG', '').startswith('ssh '))
for label in ['login-bash', 'official-bash', 'worktree-bash', 'starship-only-bash']:
    r = by_id[label + '-local-return']
    check(label + ': SSH 終了後のローカルコピー', r['copied'] == 'LOCAL_RETURN_OUTPUT')
    check(label + ': SSH 終了後のローカル cwd/プログラム', r['running_program'] == 'bash' and r['cwd'].startswith('file:///C:/'))
    check(label + ': SSH 終了後の実行変数を消去', r['vars'].get('WEZTERM_PROG', '') == '')

for label in ['login-bash', 'official-bash', 'login-native']:
    r = by_id[label + '-output']
    marker = 'REMOTE_' + label.upper().replace('-', '_') + '_OUTPUT'
    check(label + ': 現設定の cwd/タブ名', r['cwd'].startswith('file://kawasaki-pi/') and 'kawasaki-pi:almalinux' in r['formatted_tab'])
    check(label + ': 現設定のパイプは1 0を保持', '__SSH_STATE__ status=0 pipeline=1 0' in by_id[label + '-pipeline-state']['pane_text'])
    check(label + ': A によるジャンプは機能', probe_ok(by_id[label + '-jump']))
    defect(label + ': 入力範囲の印Bが消失', not input_contains(r, marker), label + '-output.json')
    defect(label + ': 直前の出力をコピーできない', r['copied'] != marker, label + '-output.json')
    defect(label + ': 独自の完了通知なし', 'wezterm_cmd_done' not in by_id[label + '-notification']['vars'], label + '-notification.json')

r = by_id['starship-only-bash-output']
check('統合なし比較: SSH全画面の誤コピーを抑止', r['copied'] is False and 'ssh 先の出力は区切れません' in r['copy_status_plain'])
check('通常ログイン: TERM_PROGRAM 未受信を実ペインでも確認', 'term=unset history=/dev/null' in by_id['login-bash-initial']['pane_text'])
defect('Git Bashの現設定: Last login行を誤コピー', str(by_id['login-bash-output']['copied']).startswith('Last login:'), 'login-bash-output.json')
result = {'snapshots': len(records), 'checks': checks,
    'confirmed': sum(c['confirmed'] for c in checks),
    'unconfirmed': sum(not c['confirmed'] for c in checks),
    'defects': defects, 'defects_reproduced': sum(c['observed'] for c in defects)}
(OUT / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(1 if result['unconfirmed'] or any(not d['observed'] for d in defects) else 0)

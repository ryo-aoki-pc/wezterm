"""SSH 修正後の実ペインを判定する。配置snapshotの比較は別集計にする。"""
import json
from pathlib import Path
import sys

DEPLOYED = '--deployed' in sys.argv[1:]
OUT = Path(__file__).resolve().parent / 'ssh-fix-results' / ('deployed-live' if DEPLOYED else 'live')
records = json.loads((OUT / 'summary.json').read_text(encoding='utf-8'))
by_id = {r['id']: r for r in records}
checks, controls = [], []
fixture_path = OUT / 'fixture.json'
fixture = json.loads(fixture_path.read_text(encoding='utf-8')) if fixture_path.exists() else {}
production_sha = fixture.get('production_sha256')
source_sha = fixture.get('source_sha256')
legacy_sha = '8ed8a09c46edd310d22369310dc44fc8d929cf93d9550ae5958062da87d12363'
# fixture のない保存済みデータは、反映前の旧配置で採取した記録。
comparison = ('legacy' if not fixture or production_sha == legacy_sha else
    'current' if production_sha and production_sha == source_sha else 'unclassified')

def check(name, condition):
    checks.append({'name': name, 'pass': bool(condition)})

def input_contains(r, text):
    return any(z['semantic_type'] == 'Input' and text in t
        for z, t in zip(r['zones'], r['zone_texts']))

labels = ['fixed-login-bash', 'fixed-login-native'] if DEPLOYED else [
    'fixed-login-bash', 'fixed-login-native', 'fixed-official-bash', 'worktree-bash', 'worktree-native']
for label in labels:
    output = by_id[label + '-output']
    marker = 'REMOTE_' + label.upper().replace('-', '_') + '_OUTPUT'
    check(label + ': 直前のリモート出力だけをコピー', output['copied'] == marker)
    check(label + ': 入力範囲の印', input_contains(output, marker))
    check(label + ': リモート cwd', output['cwd'].startswith('file://kawasaki-pi/'))
    check(label + ': 本番のタブ名', 'kawasaki-pi:almalinux' in output['formatted_tab'])
    running = by_id[label + '-running']
    if label.startswith('fixed-') and not label.endswith('native'):
        # 公式 user-vars は remote のプログラム名を送る。その処理は温存する。
        check(label + ': 実行中の遠隔プログラム/ホスト表示', running['running_program'] == 'sleep'
            and running['vars'].get('WEZTERM_PROG') == 'sleep 2.2; false'
            and 'kawasaki-pi:almalinux' in running['formatted_tab'])
    else:
        check(label + ': 実行中の SSH 判定', running['running_program'] == 'ssh')
    check(label + ': false の終了コード1', '__SSH_STATE__ status=1 pipeline=1' in by_id[label + '-failure-state']['pane_text'])
    check(label + ': パイプ個別ステータス1 0', '__SSH_STATE__ status=0 pipeline=1 0' in by_id[label + '-pipeline-state']['pane_text'])
    done = by_id[label + '-notification']['vars'].get('wezterm_cmd_done', '')
    check(label + ': 失敗の完了通知データ', done.startswith('1\t') and done.endswith('\tsleep 2.2; false'))
    lines = '\n'.join('SSH_LINE_' + str(i) for i in range(1, 71))
    jump = by_id[label + '-jump']
    check(label + ': 70行の出力コピー', jump['copied'] == lines)
    check(label + ': プロンプト移動先', bool(jump.get('prompt_probe_line', '').strip())
        and jump['prompt_probe_line'].strip() == jump.get('prompt_probe_expected', '').strip()
        and jump['prompt_target_row'] < jump['dimensions']['physical_top'])
    check(label + ': 空 Enter 後の出力保持', by_id[label + '-empty-enter']['copied'] == lines)
    if label.startswith('fixed-'):
        check(label + ': 複数行入力の出力コピー', by_id[label + '-multiline']['copied'] == 'MULTILINE_START\nMULTILINE_END')
        check(label + ': サブシェルの出力範囲', by_id[label + '-subshell']['copied'] == 'SUBSHELL_OUTPUT')
        check(label + ': サブシェルの終了コード7', '__SSH_STATE__ status=7 pipeline=7' in by_id[label + '-subshell-state']['pane_text'])
        check(label + ': Starship 単独再初期化後のコピー', by_id[label + '-reinit']['copied'] == 'REINIT_OUTPUT')
        check(label + ': 統合再読込後のコピー', by_id[label + '-resource']['copied'] == 'RESOURCE_OUTPUT')

for label in ['fixed-login-bash', 'fixed-official-bash', 'worktree-bash', 'login-bash']:
    if label + '-local-return' not in by_id:
        continue
    r = by_id[label + '-local-return']
    check(label + ': SSH 終了後のローカル出力', r['copied'] == 'LOCAL_RETURN_OUTPUT')
    check(label + ': SSH 終了後のローカル cwd/プログラム', r['running_program'] == 'bash' and r['cwd'].startswith('file:///C:/'))
    check(label + ': SSH 終了後の実行変数を消去', r['vars'].get('WEZTERM_PROG', '') == '')

for label in ['fixed-login-bash', 'fixed-login-native']:
    check(label + ': TERM_PROGRAM 未受信の通常プロファイル', 'term=unset history=/dev/null' in by_id[label + '-initial']['pane_text'])

for label in ([] if DEPLOYED else ['login-bash', 'login-native']):
    output = by_id[label + '-output']
    marker = 'REMOTE_' + label.upper().replace('-', '_') + '_OUTPUT'
    copied = output['copied'] == marker
    marked = input_contains(output, marker)
    notified = 'wezterm_cmd_done' in by_id[label + '-notification']['vars']
    observed = (not copied and not marked and not notified) if comparison == 'legacy' else (
        copied and marked and notified) if comparison == 'current' else None
    controls.append({'name': label + ': 配置snapshotの比較', 'kind': comparison,
        'observed': observed, 'copied_current_output': copied,
        'input_marked': marked, 'completion_notified': notified})

result = {'snapshots': len(records), 'checks': checks,
    'passed': sum(c['pass'] for c in checks), 'failed': sum(not c['pass'] for c in checks),
    'controls': controls, 'controls_confirmed': sum(c['observed'] is True for c in controls),
    'controls_unclassified': sum(c['observed'] is None for c in controls)}
(OUT / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({k: v for k, v in result.items() if k != 'checks'}, ensure_ascii=False, indent=2))
if result['failed']:
    print(json.dumps([c for c in checks if not c['pass']], ensure_ascii=False, indent=2))
raise SystemExit(bool(result['failed'] or any(c['observed'] is False for c in controls)))

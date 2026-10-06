"""保存した実ペイン計測を確認する。既知不具合の再現と正常機能を区別する。"""
import json
from pathlib import Path
import argparse

out = Path(__file__).resolve().parent / 'live-results'
parser = argparse.ArgumentParser()
parser.add_argument('--fix', action='store_true')
args = parser.parse_args()
if args.fix:
    out = out.parent / 'fix-results' / 'live'
records = json.loads((out / 'summary.json').read_text(encoding='utf-8'))
by_id = {r['id']: r for r in records}
checks = []
def check(name, kind, actual):
    checks.append({'name': name, 'kind': kind, 'confirmed': bool(actual)})

check('Starship なしでは直前の出力だけをコピー', 'normal', by_id['baseline-output']['copied'] == 'BASE_OUTPUT')
if args.fix:
    check('Starship Bash の Prompt/Input/Output 範囲', 'normal', {z['semantic_type'] for z in by_id['starship-output']['zones']} == {'Prompt', 'Input', 'Output'})
    check('Starship Bash の直前の出力だけコピー', 'normal', by_id['starship-output']['copied'] == 'STAR_OUTPUT')
    check('同一ペイン後付けでも直前の出力だけコピー', 'normal', by_id['baseline-then-starship']['copied'] == 'AFTER_THEME_OUTPUT')
    for label in ['starship', 'baseline']:
        r = by_id[label + '-prompt-jump']
        line = r.get('prompt_probe_line', '').strip()
        expected = r.get('prompt_probe_expected', '').strip()
        check(label + ': プロンプトジャンプ後の可視範囲', 'normal', bool(line) and line == expected and r['prompt_target_row'] < r['dimensions']['physical_top'])
else:
    check('Starship Bash は Output 範囲だけ', 'defect', {z['semantic_type'] for z in by_id['starship-output']['zones']} == {'Output'})
    check('Starship Bash のコピーは要シェル統合メッセージ', 'defect', by_id['starship-output']['copied'] is False and '要シェル統合' in by_id['starship-output']['copy_status_plain'])
    check('同一ペイン後付けではプロンプトと新コマンドまで誤コピー', 'defect', "printf 'AFTER_THEME_OUTPUT" in by_id['baseline-then-starship']['copied'] and 'OK>' in by_id['baseline-then-starship']['copied'])
check('日本語・空白・#・% の cwd を分割へ引継ぎ', 'normal', by_id['starship-cwd']['cwd'] == by_id['starship-split-cwd']['cwd'] and '%23%25' in by_id['starship-cwd']['cwd'])
check('リサイズモード', 'normal', by_id['starship-resize-mode']['key_table'] == 'resize_pane')
check('コピーモード', 'normal', by_id['starship-copy-mode']['key_table'] == 'copy_mode')
zoom = json.loads((out / 'zoomed.json').read_text(encoding='utf-8'))
check('ズームの切替', 'normal', any(r['is_zoomed'] for r in zoom))
notification = by_id['starship-notification']['vars'].get('wezterm_cmd_done', '')
check('Bash の実通知データは失敗コード1', 'normal', notification.startswith('1\t') and notification.endswith('sleep 2.2; false'))
for label in ['pwsh', 'windows-powershell']:
    check(label + ': 出力コピー', 'normal', by_id[label + '-output']['copied'] == 'PS_OUTPUT')
    check(label + ': native 失敗は Starship ERR/7', 'normal', 'STATUS=7' in by_id[label + '-native-failure']['pane_text'] and 'ERR>' in by_id[label + '-native-failure']['pane_text'])
    check(label + ': 空 Enter は直前の出力を維持', 'normal', by_id[label + '-empty-enter']['copied'] == by_id[label + '-cmdlet-failure']['copied'])
    check(label + ': 実履歴から通知データ0/2秒', 'normal', by_id[label + '-notification']['vars']['wezterm_cmd_done'] == '0\t2\tStart-Sleep -Seconds 2')

result = {'snapshots': len(records), 'checks': checks, 'confirmed': sum(r['confirmed'] for r in checks), 'unconfirmed': sum(not r['confirmed'] for r in checks)}
(out / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
raise SystemExit(1 if result['unconfirmed'] else 0)

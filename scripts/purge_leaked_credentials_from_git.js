/**
 * Public repoda commitlenmiş firebase-adminsdk JSON dosyasını git geçmişinden siler.
 * Sonrasında force push gerekir.
 *
 * Kullanım: node scripts/purge_leaked_credentials_from_git.js
 */
const { spawnSync } = require('child_process');
const path = require('path');

const LEAKED = 'dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json';
const repoRoot = path.join(__dirname, '..');

function run(cmd, args, opts = {}) {
  const r = spawnSync(cmd, args, { cwd: repoRoot, encoding: 'utf8', ...opts });
  if (r.status !== 0) {
    throw new Error((r.stderr || r.stdout || `${cmd} failed`).trim());
  }
  return (r.stdout || '').trim();
}

function main() {
  console.log('Git geçmişinde sızan dosya aranıyor:', LEAKED);
  const hits = run('git', ['log', '--all', '--pretty=format:%H', '--', LEAKED]);
  if (!hits) {
    console.log('Geçmişte dosya bulunamadı — temiz.');
    return;
  }

  console.log('filter-branch çalıştırılıyor (birkaç dakika sürebilir)...');
  run('git', [
    'filter-branch',
    '-f',
    '--index-filter',
    `git rm --cached --ignore-unmatch ${LEAKED}`,
    '--prune-empty',
    '--',
    '--all',
  ]);

  run('git', ['for-each-ref', '--format=delete %(refname)', 'refs/original/']).split('\n')
    .filter(Boolean)
    .forEach((line) => {
      const ref = line.replace(/^delete /, '');
      spawnSync('git', ['update-ref', '-d', ref], { cwd: repoRoot });
    });

  run('git', ['reflog', 'expire', '--expire=now', '--all']);
  run('git', ['gc', '--prune=now', '--aggressive']);

  console.log('');
  console.log('Git geçmişi temizlendi.');
  console.log('Uzak repoya göndermek için (dikkat: geçmiş yeniden yazılır):');
  console.log('  git push origin --force --all');
  console.log('  git push origin --force --tags');
}

main();

#!/usr/bin/env python3
"""Restore missing official HTML documentation without changing iOS libraries."""
import argparse
import hashlib
import pathlib
import re
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / 'documentations'
ARCHIVES = {
    # Official series documentation, not a different runtime/library build.
    'numpy': ('https://numpy.org/doc/1.22/numpy-html.zip', None, None),
    'pywt': ('https://pywavelets.readthedocs.io/_/downloads/en/v1.1.1/htmlzip/', None, None),
    'sklearn': (
        'https://raw.githubusercontent.com/scikit-learn/scikit-learn.github.io/'
        '355fccc608937a97d0d45654ce85ec73bd1d50e1/0.24/_downloads/scikit-learn-docs.zip',
        'b4f26dce5494f49ff6960941d973643eafd4b4b6', 67565863,
    ),
}
SITES = {
    'matplotlib': ('https://github.com/matplotlib/matplotlib.github.com.git',
                   '20a97140354021c1cad4fd664ead6d8f21aefa0a', '3.3.3'),
    'skimage': ('https://github.com/scikit-image/docs.git',
                '7c08157c13906338ce650ce96b4a1854c6377c2c', '0.18.x'),
    # The official site retains 0.13.5 for the 0.13 documentation series.
    # This is documentation only; the iOS runtime remains pinned to 0.13.1.
    'statsmodels': ('https://github.com/statsmodels/statsmodels.github.io.git',
                   '47098dfdebda9d34c8233d20edd84dc533f726a2', 'v0.13.5'),
}


def safe_parts(name):
    path = pathlib.PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name:
        raise ValueError('Unsafe documentation archive path: ' + name)
    return path.parts


def verify_archive(path):
    if not path.is_file() or not zipfile.is_zipfile(path):
        return False
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        for name in names:
            safe_parts(name)
        has_index = any(pathlib.PurePosixPath(name).name == 'index.html' for name in names)
        # Official single-page HTML distributions (including PyWavelets) are
        # complete with index.html alone. Page count is not an integrity check.
        if not has_index:
            return False
        bad = archive.testzip()
        if bad:
            raise RuntimeError('Corrupt documentation member: ' + bad)
    return True


def repack(package, downloaded):
    target = DOCS / (package + '.zip')
    partial = target.with_suffix('.zip.partial')
    with zipfile.ZipFile(downloaded) as source:
        indexes = [n for n in source.namelist() if pathlib.PurePosixPath(n).name == 'index.html']
        if not indexes:
            raise RuntimeError('Official archive has no HTML index: ' + package)
        entry = min(indexes, key=lambda n: (len(safe_parts(n)), len(n)))
        prefix = str(pathlib.PurePosixPath(entry).parent)
        prefix = '' if prefix == '.' else prefix + '/'
        with zipfile.ZipFile(partial, 'w', zipfile.ZIP_DEFLATED) as out:
            for item in source.infolist():
                safe_parts(item.filename)
                if item.is_dir() or not item.filename.startswith(prefix):
                    continue
                relative = item.filename[len(prefix):]
                if relative:
                    with source.open(item) as data, out.open(package + '/' + relative, 'w') as dest:
                        shutil.copyfileobj(data, dest)
    if not verify_archive(partial):
        raise RuntimeError('Incomplete repacked HTML documentation: ' + package)
    partial.replace(target)


def restore_archives(work):
    for package, (url, blob_sha, expected_size) in ARCHIVES.items():
        if verify_archive(DOCS / (package + '.zip')):
            print(package + ': valid existing HTML archive', flush=True)
            continue
        downloaded = work / (package + '.zip')
        print(package + ': downloading official HTML archive ' + url, flush=True)
        request = urllib.request.Request(url, headers={'User-Agent': 'Pyto-source-documentation-build'})
        with urllib.request.urlopen(request, timeout=180) as response, downloaded.open('wb') as dest:
            shutil.copyfileobj(response, dest)
        if expected_size and downloaded.stat().st_size != expected_size:
            raise RuntimeError('Official archive size mismatch: ' + package)
        if blob_sha:
            digest = hashlib.sha1(('blob %d\0' % downloaded.stat().st_size).encode())
            with downloaded.open('rb') as data:
                for chunk in iter(lambda: data.read(1024 * 1024), b''):
                    digest.update(chunk)
            if digest.hexdigest() != blob_sha:
                raise RuntimeError('Pinned official Git blob mismatch: ' + package)
        sha256 = hashlib.sha256()
        with downloaded.open('rb') as data:
            for chunk in iter(lambda: data.read(1024 * 1024), b''):
                sha256.update(chunk)
        print(package + ': downloaded SHA-256 ' + sha256.hexdigest(), flush=True)
        repack(package, downloaded)
        downloaded.unlink()


def restore_sites(work):
    for package, (url, revision, folder) in SITES.items():
        target = DOCS / (package + '.zip')
        if verify_archive(target):
            print(package + ': valid existing HTML archive', flush=True)
            continue
        checkout = work / package
        checkout.mkdir()
        commands = [
            ['git', 'init', '--quiet'],
            ['git', 'remote', 'add', 'origin', url],
            ['git', 'sparse-checkout', 'init', '--cone'],
            ['git', 'sparse-checkout', 'set', folder],
            ['git', '-c', 'protocol.version=2', 'fetch', '--depth=1', '--filter=blob:none', 'origin', revision],
            ['git', '-c', 'advice.detachedHead=false', 'checkout', '--quiet', '--detach', 'FETCH_HEAD'],
        ]
        print(package + ': restoring official HTML snapshot ' + url + '@' + revision, flush=True)
        for command in commands:
            subprocess.run(command, cwd=checkout, check=True)
        actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=checkout, text=True).strip()
        if actual != revision:
            raise RuntimeError('Official documentation snapshot mismatch: ' + package)
        html = checkout / folder
        if not (html / 'index.html').is_file():
            raise RuntimeError('Official HTML snapshot lacks index: ' + package)
        partial = target.with_suffix('.zip.partial')
        with zipfile.ZipFile(partial, 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(html.rglob('*')):
                if path.is_symlink():
                    raise RuntimeError('Unexpected symlink in official documentation: ' + str(path))
                if path.is_file():
                    archive.write(path, package + '/' + path.relative_to(html).as_posix())
        if not verify_archive(partial):
            raise RuntimeError('Incomplete official HTML snapshot: ' + package)
        partial.replace(target)
        shutil.rmtree(checkout)


def validate_all():
    # This upstream metadata has trailing commas; extract only filename fields.
    required = re.findall(r'"filename"\s*:\s*"([^"/]+\.zip)"', (DOCS / 'docs.json').read_text())
    if len(required) < 20:
        raise RuntimeError('Cannot discover required bundled documentation archives')
    missing = [name for name in required if not verify_archive(DOCS / name)]
    if missing:
        raise RuntimeError('Missing/incomplete bundled HTML documentation: ' + ', '.join(missing))
    print('Validated %d complete HTML documentation archives' % len(required), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--validate', action='store_true')
    args = parser.parse_args()
    if args.validate:
        validate_all()
    else:
        with tempfile.TemporaryDirectory(prefix='pyto-official-docs-') as work:
            restore_archives(pathlib.Path(work))
            restore_sites(pathlib.Path(work))


if __name__ == '__main__':
    main()

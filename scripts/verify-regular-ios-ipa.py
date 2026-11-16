#!/usr/bin/env python3
"""Prüft die reguläre RED-Bit-IPA einschließlich Widget, ohne Testidentität."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import plistlib
import re
import struct
import zipfile


def inspect_device_binary(data, inspector, executable=False):
    """XCFrameworks dürfen einen Universal-Container mit arm64-Geräteslices liefern."""
    magic = data[:4]
    if magic not in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        inspector(data, executable)
        return
    if len(data) < 8:
        raise ValueError('Abgeschnittener Universal-Header.')
    count = struct.unpack_from('>I', data, 4)[0]
    width = 20 if magic == b'\xca\xfe\xba\xbe' else 32
    if not 1 <= count <= 8 or len(data) < 8 + count * width:
        raise ValueError('Ungültige Universal-Sliceanzahl.')
    ranges = []
    for index in range(count):
        entry = struct.unpack_from('>IIIII' if width == 20 else '>IIQQII', data, 8 + index * width)
        cpu, _, offset, size, alignment = entry[:5]
        if cpu != 0x0100000C or alignment > 30 or offset % (1 << alignment):
            raise ValueError('Keine passende arm64-Geräteslice.')
        if size < 32 or offset < 8 + count * width or offset + size > len(data):
            raise ValueError('Universal-Slice außerhalb der Datei.')
        if any(offset < end and offset + size > start for start, end in ranges):
            raise ValueError('Überlappende Universal-Slices.')
        ranges.append((offset, offset + size))
        inspector(data[offset:offset + size], executable)


def verify(ipa: Path, source_sha: str):
    if not re.fullmatch(r'[a-f0-9]{40}', source_sha):
        raise ValueError('Vollständige Commit-ID erforderlich.')
    spec = importlib.util.spec_from_file_location('device_macho', Path(__file__).with_name('verify-ios-test-ipa.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any('..' in PurePosixPath(n).parts or n.startswith('/') for n in names):
            raise ValueError('Unsichere oder doppelte ZIP-Pfade.')
        roots = [n for n in names if re.fullmatch(r'Payload/[^/]+\.app/Info\.plist', n)]
        if len(roots) != 1:
            raise ValueError('Genau eine Geräte-App erwartet.')
        root = roots[0].removesuffix('Info.plist')
        app = plistlib.loads(archive.read(roots[0]))
        if app.get('CFBundleIdentifier') != 'com.babat.bbtbit' or app.get('CFBundleDisplayName') != 'RED Bit':
            raise ValueError('Reguläre App-Identität fehlt.')
        if app.get('RedBitRevision') != source_sha[:12] or any(k.startswith('BBTTest') for k in app):
            raise ValueError('Quellrevision falsch oder Testkonfiguration enthalten.')
        if app.get('CFBundleSupportedPlatforms') != ['iPhoneOS'] or 'audio' not in app.get('UIBackgroundModes', []):
            raise ValueError('Geräteplattform oder Hintergrundaudio fehlt.')
        widget_plist = root + 'PlugIns/RedBitWidget.appex/Info.plist'
        widget = plistlib.loads(archive.read(widget_plist))
        if widget.get('CFBundleIdentifier') != 'com.babat.bbtbit.widget':
            raise ValueError('Reguläres Widget fehlt.')
        for key in ['CFBundleShortVersionString', 'CFBundleVersion']:
            if app.get(key) != widget.get(key) or not app.get(key):
                raise ValueError('App und Widget haben abweichende Versionen.')
        binaries = [root + app['CFBundleExecutable'], widget_plist.removesuffix('Info.plist') + widget['CFBundleExecutable']]
        frameworks = []
        for name in names:
            if name.startswith(root + 'Frameworks/') and name.endswith('.framework/Info.plist'):
                info = plistlib.loads(archive.read(name))
                binaries.append(name.removesuffix('Info.plist') + info['CFBundleExecutable'])
                frameworks.append(info['CFBundleExecutable'])
        if not {'NativeCoreFFI', 'RedBitShared'}.issubset(frameworks):
            raise ValueError('Native Audio-/Shared-Frameworks fehlen.')
        for name in binaries:
            with archive.open(name) as binary:
                inspect_device_binary(binary.read(), module.inspect_macho, name == binaries[0])
        if any(n.endswith(('embedded.mobileprovision', 'embedded.provisionprofile')) for n in names):
            raise ValueError('Im unsignierten Paket wurde ein Profil gefunden.')
    with ipa.open('rb') as file:
        digest = hashlib.file_digest(file, 'sha256').hexdigest()
    return dict(status='BESTANDEN', signing='UNSIGNIERT – externe Signierung erforderlich',
                ipa=ipa.name, source_sha=source_sha, bundle_id=app['CFBundleIdentifier'],
                version=app['CFBundleShortVersionString'], build=app['CFBundleVersion'],
                widget=widget['CFBundleIdentifier'], frameworks=frameworks, sha256=digest,
                limitation='Paketstruktur und Gerätebinaries geprüft; Installation, Signierung und Laufzeit nicht bestätigt.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = verify(args.ipa, args.source_sha)
    output = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.report:
        args.report.write_text(output, encoding='utf-8')
    print(output)

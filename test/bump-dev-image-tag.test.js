// scripts/bump-dev-image-tag.sh is the step of the Bump commit that points the
// dev Environment at a Release's image. These tests run it the way the
// release workflow does, against a copy of the dev values file, and check
// what it leaves in that file.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const root = path.join(__dirname, '..');
const script = path.join(root, 'scripts', 'bump-dev-image-tag.sh');
const devValues = path.join(root, 'gitops', 'charts', 'sample-nodejs', 'values-dev.yaml');

// A copy of the dev values in a fresh temp directory, removed after the test.
function copyOfDevValues(t) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bump-dev-image-tag-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'values-dev.yaml');
    fs.copyFileSync(devValues, file);
    return file;
}

function bump(version, valuesFile) {
    return spawnSync('bash', [script, version], {
        env: { ...process.env, DEV_VALUES: valuesFile },
        encoding: 'utf8',
    });
}

// The lines that differ between two versions of a file of the same length.
function changedLines(before, after) {
    const a = before.split('\n');
    const b = after.split('\n');
    assert.equal(b.length, a.length, 'the script added or removed lines');
    return a.flatMap((line, i) => (line === b[i] ? [] : [{ before: line, after: b[i] }]));
}

test('sets the dev image tag to the version and changes no other line', (t) => {
    const file = copyOfDevValues(t);
    const before = fs.readFileSync(file, 'utf8');

    const result = bump('1.2.3', file);

    assert.equal(result.status, 0, result.stderr);
    const changes = changedLines(before, fs.readFileSync(file, 'utf8'));
    assert.equal(changes.length, 1, `expected one changed line, got ${JSON.stringify(changes)}`);
    assert.equal(changes[0].after, '  tag: 1.2.3');
});

// Only a plain MAJOR.MINOR.PATCH, the form semantic-release gives a Release on
// main and the form the image is tagged with in GHCR.
for (const version of ['', 'v1.2.3', '1.2', '1.2.3.4', '01.2.3', '1.2.3-rc.1', 'latest', '1.2.3 # x', '1.2.3\ntag: 9.9.9']) {
    test(`refuses the malformed version ${JSON.stringify(version)} and leaves the file unchanged`, (t) => {
        const file = copyOfDevValues(t);
        const before = fs.readFileSync(file, 'utf8');

        const result = bump(version, file);

        assert.notEqual(result.status, 0, 'the script accepted a malformed version');
        assert.match(result.stderr, /version/);
        assert.equal(fs.readFileSync(file, 'utf8'), before);
    });
}

// Without this, a reshaped values file would leave nothing to commit, and the
// Bump commit would stand down green while dev stays on the old image.
test('fails when the values file has no image tag, and leaves the file unchanged', (t) => {
    const file = copyOfDevValues(t);
    const withoutTag = 'image:\n  repository: ghcr.io/sela27/sample-nodejs\n\ningress:\n  tag: not-the-image\n';
    fs.writeFileSync(file, withoutTag);

    const result = bump('1.2.3', file);

    assert.notEqual(result.status, 0, 'the script succeeded without an image tag to set');
    assert.match(result.stderr, /image\.tag/);
    assert.equal(fs.readFileSync(file, 'utf8'), withoutTag);
});

//
// Copyright 2026 Perforce Software
//
import { assert } from 'chai'
import { describe, it } from 'mocha'
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const script = join(__dirname, '..', 'bin', 'fix-exttabs.py')
const spacesFixture = join(__dirname, 'fixtures', 'fix-exttabs-spaces.txt')
const tabsFixture = join(__dirname, 'fixtures', 'fix-exttabs-tabs.txt')

// Run the fixer with the given file on stdin and return its stdout.
function runFixer (inputFile) {
  return execFileSync('python3', [script], {
    input: readFileSync(inputFile),
    encoding: 'utf8'
  })
}

// Ignore incidental differences in trailing blank lines at end-of-file.
function trimTrailing (text) {
  return text.replace(/\n+$/, '\n')
}

describe('fix-exttabs.py', function () {
  it('converts space indentation to the expected tabs', function () {
    const actual = runFixer(spacesFixture)
    const expected = readFileSync(tabsFixture, 'utf8')
    assert.equal(trimTrailing(actual), trimTrailing(expected))
  })

  it('leaves a correctly tabbed configuration unchanged', function () {
    const actual = runFixer(tabsFixture)
    const expected = readFileSync(tabsFixture, 'utf8')
    assert.equal(trimTrailing(actual), trimTrailing(expected))
  })

  it('indents the ExtConfig block with tabs only', function () {
    const actual = runFixer(spacesFixture)
    const lines = actual.split('\n')
    const start = lines.findIndex((line) => line.startsWith('ExtConfig:'))
    assert.isAbove(start, 0, 'expected an ExtConfig block in the output')
    for (let i = start + 1; i < lines.length; i++) {
      const line = lines[i]
      // the block ends at the first non-blank, non-indented line
      if (line !== '' && !/^\s/.test(line)) break
      if (line.trim() === '') continue
      assert.match(line, /^\t{1,2}[^\t]/, `line should be tab-indented: "${line}"`)
    }
  })
})

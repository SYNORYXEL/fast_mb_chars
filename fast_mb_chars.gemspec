# frozen_string_literal: true

$:.push File.expand_path('lib', __dir__)

require 'fast_mb_chars/version'

Gem::Specification.new do |spec|
  spec.name = 'fast_mb_chars'
  spec.version = FastMbChars::VERSION
  spec.authors = ['SYNORYXEL']
  spec.email = ['mike.pvlv@icloud.com']
  spec.homepage = 'https://github.com/SYNORYXEL/fast_mb_chars'
  spec.summary = 'Faster Ruby String#mb_chars. Byte limit that keeps UTF-8 characters whole'
  spec.description = <<~TEXT
    Faster String#mb_chars. limit(bytes) cuts on a character boundary without
    walking the whole string and without raising on a broken byte. A 1 MB cut
    is about 2,000 times faster than the ActiveSupport grapheme scan, and a
    7 MB cut is about 3,000 times faster.

    downcase, upcase, titleize, reverse, split, slice!, compose, decompose,
    tidy_bytes, and the other string methods are forwarded through method_missing.
    They still return mb_chars, so existing chains keep working.
  TEXT
  spec.license = 'MIT'
  spec.files = Dir['lib/**/*.rb', 'README.md', 'LICENSE', 'CHANGELOG.md', 'benchmark/compare.rb', 'docs/**/*']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/SYNORYXEL/fast_mb_chars',
    'changelog_uri' => 'https://github.com/SYNORYXEL/fast_mb_chars/blob/main/CHANGELOG.md',
    'bug_tracker_uri' => 'https://github.com/SYNORYXEL/fast_mb_chars/issues',
    'allowed_push_host' => 'https://rubygems.org',
    'rubygems_mfa_required' => 'true'
  }
end

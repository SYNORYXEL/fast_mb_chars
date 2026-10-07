# frozen_string_literal: true

# ruby benchmark/compare.rb
# rake benchmark

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'fast_mb_chars'

# What ActiveSupport::Multibyte::Chars#limit does: walk every grapheme from
# the start and never go past the byte budget.
def walk_limit(text, max_bytes)
  text = text.to_s
  return +'' if max_bytes <= 0 || text.empty?
  return text.dup if text.bytesize <= max_bytes

  taken = 0
  text.each_grapheme_cluster do |cluster|
    size = cluster.bytesize
    break if taken + size > max_bytes

    taken += size
  end
  text.byteslice(0, taken)
end

SIZES = [
  ['1 KB', 1_024, 300],
  ['8 KB', 8_192, 150],
  ['64 KB', 65_536, 40],
  ['256 KB', 262_144, 15],
  ['1 MB', 1_048_576, 8],
  ['7 MB', 7_340_032, 3]
].freeze

# The string is longer than the limit, so both sides actually cut.
# split puts one 2-byte letter across the boundary.
def payload(kind, bytes)
  case kind
  when :ascii
    ['a' * (bytes + 64), bytes]
  when :cyrillic
    ['я' * ((bytes / 2) + 16), bytes]
  when :split
    [(('a' * (bytes - 1)) + 'я'), bytes]
  end
end

def time_ms(iterations)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  iterations.times { yield }
  ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) / iterations) * 1000.0
end

rows = []

puts "ruby #{RUBY_VERSION}  fast_mb_chars #{FastMbChars::VERSION}"
puts "limit vs full grapheme walk (ms per call, one process)"
puts

%i[ascii cyrillic split].each do |kind|
  puts kind
  puts format('%-8s %10s %10s %8s  %s', 'size', 'walk', 'fast', 'times', 'result')
  SIZES.each do |label, bytes, iterations|
    text, limit = payload(kind, bytes)
    2.times { walk_limit(text, limit) }
    2.times { FastMbChars::Limiter.limit(text, limit) }
    slow = time_ms(iterations) { walk_limit(text, limit) }
    fast = time_ms(iterations) { FastMbChars::Limiter.limit(text, limit) }
    ratio = fast.positive? ? slow / fast : 0
    cut = FastMbChars::Limiter.limit(text, limit)
    rows << [kind, label, slow, fast, ratio, cut.bytesize, limit]
    puts format('%-8s %10.3f %10.3f %7.0fx  %d/%d bytes', label, slow, fast, ratio, cut.bytesize, limit)
  end
  puts
end

small = 'ГОТІВКА'
time_ms(1000) { small.mb_chars.downcase.to_s }
down = time_ms(20_000) { small.mb_chars.downcase.to_s }
plain = time_ms(20_000) { small.downcase }
puts format('downcase %s  mb_chars %.4f ms   String#downcase %.4f ms', small, down, plain)

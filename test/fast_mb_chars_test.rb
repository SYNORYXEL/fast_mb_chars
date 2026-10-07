# frozen_string_literal: true

require 'minitest/autorun'
require 'fast_mb_chars'

class FastMbCharsTest < Minitest::Test
  def limit(text, max_bytes)
    text.mb_chars.limit(max_bytes).to_s
  end

  def test_downcase_and_upcase_chain
    assert_equal 'київ', 'Київ'.mb_chars.downcase.to_s
    assert_equal 'готівка', 'ГОТІВКА'.to_s.mb_chars.downcase.to_s
    assert_equal 'КИЇВ', 'київ'.mb_chars.upcase.to_s
    assert_equal '', ''.mb_chars.downcase.to_s
    assert_equal '', nil.to_s.mb_chars.downcase.to_s
  end

  def test_empty_and_under_limit_keep_the_tail
    assert_equal '', limit('', 10)
    assert_equal '', limit('   ', 0)
    assert_equal 'ok!!!', limit('ok!!!', 10)
    assert_equal 'hello ', limit('hello ', 10)
    assert_equal 'Київ', limit('Київ', 1_048_576)
  end

  def test_ascii_cut_is_exact
    text = 'x' * 200
    assert_equal 'x' * 100, limit(text, 100)
    assert_equal 100, limit(text, 100).bytesize
  end

  def test_cyrillic_boundary_stays_between_letters
    text = 'я' * 10
    cut = limit(text, 8)
    assert_equal 'я' * 4, cut
    assert_equal 8, cut.bytesize
  end

  def test_split_cyrillic_letter_is_kept_whole
    text = ('a' * 3) + 'я'
    cut = limit(text, 4)
    assert_equal 'aaaя', cut
    assert_equal 5, cut.bytesize
  end

  def test_combining_mark_on_the_boundary_is_kept
    text = ('a' * 3) + "e\u0301"
    cut = limit(text, 4)
    assert_equal "aaae\u0301", cut
  end

  def test_emoji_on_the_boundary_is_kept
    text = ('a' * 4) + '👨‍👩‍👧‍👦'
    cut = limit(text, 10)
    assert_equal text, cut
    assert cut.bytesize > 10
  end

  def test_very_long_combining_run_is_dropped_without_raising
    text = 'a' + ("\u0301" * 200)
    cut = limit(text, 80)
    assert cut.valid_encoding?
    assert_operator cut.bytesize, :<=, 80
  end

  def test_invalid_byte_does_not_raise
    bin = ('a' * 60).b
    bin.setbyte(30, 0xFF)
    cut = limit(bin, 64)
    assert_equal 60, cut.bytesize

    long = ('a' * 100).b
    long.setbyte(30, 0xFF)
    assert_operator limit(long, 64).bytesize, :<=, 64
  end

  def test_crlf_is_not_split
    text = ('a' * 63) + "\r\n"
    cut = limit(text, 64)
    assert_equal text, cut
  end

  def test_seven_megabyte_limit_keeps_a_crossing_letter
    max = 7_340_032
    text = ('a' * (max - 1)) + 'я'
    cut = limit(text, max)
    assert_equal text, cut
    assert cut.end_with?('я')
  end

  def test_length_is_characters
    assert_equal 4, 'Київ'.mb_chars.length
    assert_equal 8, 'Київ'.mb_chars.to_s.bytesize
  end

  def test_mb_chars_methods
    assert_equal 'éfac', 'cafÉ'.mb_chars.reverse.downcase.to_s
    assert_equal 'Él Que Se Enteró', 'ÉL QUE SE ENTERÓ'.mb_chars.titleize.to_s
    assert_equal '日本語', '日本語'.mb_chars.titlecase.to_s
    assert_equal ['CAF', ' P', 'RIFERÔL'], 'Café périferôl'.mb_chars.split(/é/).map { |part| part.upcase.to_s }

    string = +'Welcome'
    assert_equal 'c', string.mb_chars.slice!(3).to_s
    assert_equal 'Welome', string

    assert_equal 2, "e\u0301".mb_chars.length
    assert_equal 1, "e\u0301".mb_chars.grapheme_length
    assert_equal 1, "e\u0301".mb_chars.compose.to_s.length
    assert_operator 'é'.mb_chars.decompose.to_s.length, :>=, 1

    tidy = "caf\xE9".b.mb_chars.tidy_bytes.to_s
    assert_equal 'café', tidy
    assert tidy.valid_encoding?

    assert_equal true, 'Київ'.mb_chars.acts_like_string?
    assert_equal 'київ', '  Київ  '.mb_chars.downcase.strip.to_s
  end

  def test_version_and_public_methods
    assert_match(/\A\d+\.\d+\.\d+\z/, FastMbChars::VERSION)

    chars = 'Київ'.mb_chars
    %i[limit downcase upcase capitalize swapcase titleize titlecase reverse
       compose decompose tidy_bytes grapheme_length split slice! strip].each do |name|
      assert_operator chars, :respond_to?, name
    end

    assert_equal 'Київ', 'київ'.mb_chars.capitalize.to_s
    assert_equal 'кИЇВ', 'Київ'.mb_chars.swapcase.to_s
    assert_equal(-1, 'а'.mb_chars <=> 'б'.mb_chars)
    assert_nil 'нема'.mb_chars.slice!(50)
  end

  def test_negative_limit_is_empty
    assert_equal '', limit('hello', -1)
  end

  def test_frozen_string_is_not_mutated
    original = 'КИЇВ'.freeze
    chars = original.mb_chars
    assert_same chars, chars.downcase!
    assert_equal 'київ', chars.to_s
    assert_equal 'КИЇВ', original
  end

  def test_wrong_arity_still_raises
    assert_raises(ArgumentError) { 'hello'.mb_chars.send(:slice) }
  end

  def test_gsub_returns_mb_chars
    result = 'Київ'.mb_chars.gsub('и', 'и')
    assert_instance_of FastMbChars::Chars, result
    assert_equal 'КИЇВ', result.upcase.to_s
  end

  def test_three_and_four_byte_characters_stay_whole
    yen = ('a' * 3) + '日'
    cut = limit(yen, 4)
    assert_equal yen, cut
    assert_equal 6, cut.bytesize
    assert_equal Encoding::UTF_8, cut.encoding

    grin = ('a' * 3) + '😀'
    cut = limit(grin, 4)
    assert_equal grin, cut
    assert_equal 7, cut.bytesize
  end

  def test_limit_does_not_mutate_the_original
    text = +('я' * 10)
    cut = limit(text, 8)
    assert_equal 'я' * 4, cut
    assert_equal 'я' * 10, text
  end

  def test_us_ascii_is_read_as_utf8
    text = 'hello'.encode(Encoding::US_ASCII)
    cut = text.mb_chars.limit(3).to_s
    assert_equal 'hel', cut
    assert_equal Encoding::UTF_8, cut.encoding
  end

  def test_limit_accepts_numeric_strings
    assert_equal 'hel', limit('hello', '3')
  end

  def test_limit_returns_chars
    result = 'Київ'.mb_chars.limit(8)
    assert_instance_of FastMbChars::Chars, result
    assert_equal 'Київ', result.to_s
  end

  def test_install_takes_the_method_back
    other = Module.new { def mb_chars; :other; end }
    String.prepend(other)
    assert_equal :other, 'x'.mb_chars

    FastMbChars.install!
    assert_instance_of FastMbChars::Chars, 'x'.mb_chars
    FastMbChars.install!
    assert_instance_of FastMbChars::Chars, 'x'.mb_chars
  ensure
    FastMbChars.install!
  end
end

# frozen_string_literal: true

module FastMbChars
  # Proxy with the same methods as ActiveSupport::Multibyte::Chars.
  # limit is the fast path. Everything else follows the string.
  class Chars
    include Comparable

    attr_reader :wrapped_string
    alias to_s wrapped_string
    alias to_str wrapped_string

    def initialize(text)
      @wrapped_string = Limiter.utf8(text)
      @wrapped_string = @wrapped_string.dup if @wrapped_string.frozen?
    end

    def limit(max_bytes)
      chars(Limiter.limit(@wrapped_string, Integer(max_bytes)))
    end

    def reverse
      chars(readable.grapheme_clusters.reverse.join)
    end

    def titleize
      chars(readable.downcase.gsub(/\b('?\S)/u) { Regexp.last_match(1).upcase })
    end
    alias titlecase titleize

    def decompose
      chars(readable.unicode_normalize(:nfd))
    end

    def compose
      chars(readable.unicode_normalize(:nfc))
    end

    def grapheme_length
      readable.grapheme_clusters.length
    end

    def tidy_bytes(force = false)
      chars(self.class.tidy_bytes(@wrapped_string, force))
    end

    def split(*args)
      readable.split(*args).map { |part| self.class.new(part) }
    end

    def slice!(*args)
      sliced = @wrapped_string.slice!(*args)
      chars(sliced) if sliced
    end

    def reverse!
      @wrapped_string = reverse.to_s
      self
    end

    def tidy_bytes!(*args)
      @wrapped_string = tidy_bytes(*args).to_s
      self
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def =~(other)
      @wrapped_string =~ other
    end

    def match?(*args)
      @wrapped_string.match?(*args)
    end

    def acts_like_string?
      true
    end

    def as_json(options = nil)
      to_s.respond_to?(:as_json) ? to_s.as_json(options) : to_s
    end

    def method_missing(method, ...)
      retried = false
      begin
        result = @wrapped_string.__send__(method, ...)
        if method.end_with?('!')
          self if result
        else
          result.is_a?(String) ? chars(result) : result
        end
      rescue ArgumentError
        raise if retried || @wrapped_string.valid_encoding?

        retried = true
        @wrapped_string = @wrapped_string.scrub
        retry
      end
    end

    def respond_to_missing?(method, include_private = false)
      @wrapped_string.respond_to?(method, include_private) || super
    end

    def self.tidy_bytes(string, force = false)
      return string if string.empty? || (string.valid_encoding? && string.ascii_only?)
      return recode_windows1252(string) if force

      string.scrub { |bad| recode_windows1252(bad) }
    end

    def self.recode_windows1252(string)
      string.encode(Encoding::UTF_8, Encoding::Windows_1252, invalid: :replace, undef: :replace)
    end
    private_class_method :recode_windows1252

    private

    def readable
      @wrapped_string.valid_encoding? ? @wrapped_string : @wrapped_string.scrub
    end

    def chars(string)
      self.class.new(string)
    end
  end
end

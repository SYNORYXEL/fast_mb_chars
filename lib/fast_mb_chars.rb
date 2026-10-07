# frozen_string_literal: true

require 'fast_mb_chars/version'
require 'fast_mb_chars/limiter'
require 'fast_mb_chars/chars'

module FastMbChars
  # Prepends a fresh module each time the method was taken over by someone
  # else. Prepending the same module twice does not move it back to the front.
  def self.install!
    if String.method_defined?(:mb_chars) && String.instance_method(:mb_chars).owner == @installed
      return
    end

    @installed = Module.new do
      def mb_chars
        FastMbChars::Chars.new(self)
      end
    end
    String.prepend(@installed)
  end

  install!
end

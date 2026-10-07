# frozen_string_literal: true

module FastMbChars
  # Cut to max_bytes without splitting a character and without reading
  # the whole string. A character that crosses the limit is kept if it ends
  # within SLACK bytes. A longer one is dropped. Invalid bytes do not raise.
  module Limiter
    SLACK = 128

    module_function

    def limit(text, max_bytes)
      text = utf8(text)
      return +'' if max_bytes <= 0 || text.empty?
      return text.dup if text.bytesize <= max_bytes

      prev = text.getbyte(max_bytes - 1)
      nxt = text.getbyte(max_bytes)
      if ascii_boundary?(prev, nxt)
        cut = text.byteslice(0, max_bytes)
        return cut if cut.valid_encoding?
      end

      cut_at_grapheme(text, max_bytes)
    rescue ArgumentError
      safe_prefix(text, max_bytes)
    end

    def utf8(text)
      text = text.to_s
      return text if text.encoding == Encoding::UTF_8

      text.dup.force_encoding(Encoding::UTF_8)
    end

    def ascii_boundary?(prev, nxt)
      prev && nxt && prev < 0x80 && nxt < 0x80 && !(prev == 0x0D && nxt == 0x0A)
    end

    def cut_at_grapheme(text, max_bytes)
      start = align_start(text, [max_bytes - SLACK, 0].max)
      hard_end = [text.bytesize, max_bytes + SLACK].min
      finish = align_end(text, hard_end, max_bytes + SLACK)
      finish = start if finish < start

      window = text.byteslice(start, finish - start)
      return safe_prefix(text, max_bytes) unless window.valid_encoding?

      rel = max_bytes - start
      taken = 0
      keep = 0
      window.each_grapheme_cluster do |cluster|
        size = cluster.bytesize
        break if taken >= rel

        if taken + size <= rel
          taken += size
          keep = taken
          next
        end

        cluster_end = start + taken + size
        if cluster_end <= max_bytes + SLACK && grapheme_closed?(text, start + taken, cluster_end)
          keep = taken + size
        elsif taken.positive?
          keep = taken
        else
          return safe_prefix(text, max_bytes)
        end
        break
      end

      text.byteslice(0, start + keep)
    end

    def grapheme_closed?(text, cluster_start, cluster_end)
      return true if cluster_end >= text.bytesize

      probe_end = next_char_end(text, cluster_end)
      return true if probe_end <= cluster_end

      sample = text.byteslice(cluster_start, probe_end - cluster_start)
      return false unless sample&.valid_encoding?

      matched = sample[/\A\X/]
      matched&.bytesize == cluster_end - cluster_start
    rescue ArgumentError
      false
    end

    def align_start(text, index)
      index = 0 if index.negative?
      return text.bytesize if index >= text.bytesize

      steps = 0
      while index.positive? && steps < 3 && continuation?(text.getbyte(index))
        index -= 1
        steps += 1
      end
      index
    end

    def align_end(text, index, hard_end)
      return 0 if index <= 0
      return text.bytesize if index >= text.bytesize
      return index unless continuation?(text.getbyte(index))

      lead = align_start(text, index)
      length = seq_length(text.getbyte(lead))
      char_end = length ? lead + length : lead
      char_end <= hard_end && char_end <= text.bytesize ? char_end : lead
    end

    def next_char_end(text, index)
      return index if index >= text.bytesize

      length = seq_length(text.getbyte(index)) || 1
      [index + length, text.bytesize].min
    end

    def seq_length(lead)
      return 1 if lead < 0x80
      return 2 if (lead & 0xE0) == 0xC0
      return 3 if (lead & 0xF0) == 0xE0
      return 4 if (lead & 0xF8) == 0xF0

      nil
    end

    def continuation?(byte)
      byte && (byte & 0xC0) == 0x80
    end

    def safe_prefix(text, max_bytes)
      limit = [max_bytes, text.bytesize].min
      if limit.positive? && limit < text.bytesize && continuation?(text.getbyte(limit))
        limit = align_start(text, limit)
      end
      cut = text.byteslice(0, limit)
      return cut if cut.valid_encoding?

      3.times do
        break if cut.empty?

        cut = cut.byteslice(0, cut.bytesize - 1)
        return cut if cut.valid_encoding?
      end

      text.byteslice(0, [max_bytes, text.bytesize].min).scrub('?')
    end
  end
end

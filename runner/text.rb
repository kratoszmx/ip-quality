# frozen_string_literal: true

module IpQuality
  module Text
    module_function

    def printable?(value, max_bytes: 512)
      value.is_a?(String) && value.valid_encoding? && !value.empty? &&
        value.bytesize <= max_bytes && !value.match?(/[[:cntrl:]]/)
    end
  end
end

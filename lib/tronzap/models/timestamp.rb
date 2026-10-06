# frozen_string_literal: true

module Tronzap
  module Models
    # A timestamp as the API sent it, together with its parsed value.
    #
    # @!attribute [r] raw
    #   @return [String] the text exactly as the API sent it
    # @!attribute [r] value
    #   @return [Time, nil] the parsed time, or +nil+ when {raw} is in a format the SDK does not recognise
    Timestamp = Data.define(:raw, :value) do
      # Parses a timestamp in any of the formats the API emits: RFC 3339 with or without an offset, a
      # space-separated date and time, a bare date, or Unix seconds. Times without an offset are read as UTC.
      #
      # @param raw [String]
      # @return [Timestamp]
      def self.parse(raw)
        raise ArgumentError, "raw must be a String" unless raw.is_a?(String)

        new(raw: raw.dup.freeze, value: parse_time(raw.strip))
      end

      def self.parse_time(text)
        if (match = /\A(\d{4})-(\d{2})-(\d{2})[T\ ](\d{2}):(\d{2})
                     (?::(\d{2}(?:\.\d+)?))?\s*(Z|[+-]\d{2}(?::?\d{2})?)?\z/ix.match(text))
          date_time(match)
        elsif (match = /\A(\d{4})-(\d{2})-(\d{2})\z/.match(text))
          calendar_day(Time.utc(*match.captures.map(&:to_i)), *match.captures)
        elsif /\A\d{1,12}\z/.match?(text)
          Time.at(text.to_i).utc
        end
      rescue ArgumentError
        nil
      end

      def self.date_time(match)
        year, month, day, hour, minute, second, zone = match.captures
        zone = "+00:00" if zone.nil? || zone.casecmp?("z")
        zone = "#{zone}:00" if zone.length == 3
        time = Time.new(year.to_i, month.to_i, day.to_i, hour.to_i, minute.to_i, Rational(second || "0"), zone)
        calendar_day(time, year, month, day)
      end

      # Time rolls an impossible date such as February 30 over into the next month instead of rejecting it.
      def self.calendar_day(time, year, month, day)
        time if [time.year, time.month, time.day] == [year.to_i, month.to_i, day.to_i]
      end
      private_class_method :parse_time, :date_time, :calendar_day

      # @return [String] the parsed time in ISO 8601, or the raw text when it could not be parsed
      def to_s
        return raw unless value

        value.iso8601(value.subsec.zero? ? 0 : 6)
      end
    end
  end
end

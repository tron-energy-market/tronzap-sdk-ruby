# frozen_string_literal: true

RSpec.describe Tronzap::Models::Timestamp do
  {
    "2026-08-01T12:00:00+00:00" => Time.utc(2026, 8, 1, 12),
    "2026-08-01T15:00:00+03:00" => Time.utc(2026, 8, 1, 12),
    "2026-08-01T12:00:00Z" => Time.utc(2026, 8, 1, 12),
    "2026-08-01T12:00:00.250000Z" => Time.utc(2026, 8, 1, 12, 0, Rational(1, 4)),
    "2026-08-01 12:00:00" => Time.utc(2026, 8, 1, 12),
    "2026-08-01T12:00" => Time.utc(2026, 8, 1, 12),
    "2026-08-01T07:00:00-0500" => Time.utc(2026, 8, 1, 12),
    "2026-08-01" => Time.utc(2026, 8, 1),
    "1785585600" => Time.utc(2026, 8, 1, 12),
    " 2026-08-01T12:00:00+00:00 " => Time.utc(2026, 8, 1, 12)
  }.each do |raw, expected|
    it "parses #{raw.inspect}" do
      timestamp = described_class.parse(raw)

      expect(timestamp.value).to eq(expected)
      expect(timestamp.raw).to eq(raw)
    end
  end

  ["", "yesterday", "2026-13-01 00:00:00", "2026-02-30", "2026-08-01T25:00:00Z", "12345678901234"].each do |raw|
    it "keeps #{raw.inspect} without a parsed value" do
      expect(described_class.parse(raw).value).to be_nil
    end
  end

  it "reads a time without an offset as UTC" do
    expect(described_class.parse("2026-08-01 12:00:00").value.utc_offset).to eq(0)
  end

  it "prints the parsed time, or the raw text when it could not be parsed" do
    expect(described_class.parse("2026-08-01 12:00:00").to_s).to eq("2026-08-01T12:00:00+00:00")
    expect(described_class.parse("someday").to_s).to eq("someday")
  end
end

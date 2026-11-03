#!/usr/bin/env ruby

require "json"
require "optparse"

module JsonlSummary
  class Summary
    attr_reader :record_count, :key_counts, :numeric_values

    def initialize
      @record_count = 0
      @key_counts = Hash.new(0)
      @numeric_values = Hash.new { |hash, key| hash[key] = [] }
    end

    def add(record, line_number = nil)
      unless record.is_a?(Hash)
        message = "each JSONL record must be a JSON object"
        message = "line #{line_number}: #{message}" if line_number
        raise ArgumentError, message
      end

      @record_count += 1
      record.each_key { |key| @key_counts[key] += 1 }
      record.each do |key, value|
        next unless value.is_a?(Numeric)
        next if value.respond_to?(:finite?) && !value.finite?
        @numeric_values[key] << value
      end
    end

    def numeric_stats(key)
      values = numeric_values[key].sort
      return nil if values.empty?

      count = values.length
      minimum = values.first
      maximum = values.last
      mean = values.sum.to_f / count
      median = if count.odd?
                 values[count / 2]
               else
                 (values[count / 2 - 1] + values[count / 2]) / 2.0
               end

      { count: count, min: minimum, max: maximum, mean: mean, median: median }
    end
  end

  def self.summarize(io)
    summary = Summary.new
    io.each_line.with_index(1) do |line, line_number|
      next if line.strip.empty?
      record =
        begin
          JSON.parse(line, allow_nan: false)
        rescue JSON::ParserError => e
          raise JSON::ParserError, "line #{line_number}: #{e.message}"
        end
      summary.add(record, line_number)
    end
    summary
  end

  def self.run(argv = ARGV, output = $stdout, error = $stderr)
    help_requested = false
    parser = OptionParser.new do |option_parser|
      option_parser.banner = "Usage: jsonl_summary.rb [FILE]"
      option_parser.on("-h", "--help", "Show this help") do
        help_requested = true
      end
    end
    parser.parse!(argv)

    if help_requested
      output.puts parser
      return 0
    end

    path = argv.shift
    unless argv.empty?
      error.puts "jsonl_summary: unexpected argument: #{argv.first}"
      return 2
    end

    io = path.nil? || path == "-" ? $stdin : File.open(path)
    summary = summarize(io)

    output.puts "records: #{summary.record_count}"
    output.puts "keys:"
    summary.key_counts.sort.each do |key, count|
      output.puts "  #{key}: #{count}"
    end
    output.puts "numeric:"
    summary.numeric_values.keys.sort.each do |key|
      stats = summary.numeric_stats(key)
      next unless stats
      output.puts "  #{key}: count=#{stats[:count]} min=#{stats[:min]} max=#{stats[:max]} mean=#{stats[:mean]} median=#{stats[:median]}"
    end
    0
  rescue OptionParser::ParseError => e
    error.puts "jsonl_summary: #{e.message}"
    2
  rescue SystemCallError => e
    error.puts "jsonl_summary: #{e.message}"
    2
  rescue JSON::ParserError => e
    error.puts "jsonl_summary: invalid JSON: #{e.message}"
    2
  rescue ArgumentError => e
    error.puts "jsonl_summary: #{e.message}"
    2
  rescue EncodingError => e
    error.puts "jsonl_summary: #{e.message}"
    2
  ensure
    if io && io != $stdin && !io.closed?
      io.close
    end
  end
end

exit JsonlSummary.run if __FILE__ == $PROGRAM_NAME

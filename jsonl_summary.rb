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

    def add(record)
      unless record.is_a?(Hash)
        raise ArgumentError, "each JSONL record must be a JSON object"
      end

      @record_count += 1
      record.each_key { |key| @key_counts[key] += 1 }
      record.each do |key, value|
        next unless value.is_a?(Numeric) && !value.is_a?(TrueClass) && !value.is_a?(FalseClass)
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
    io.each_line do |line|
      next if line.strip.empty?
      summary.add(JSON.parse(line))
    end
    summary
  end

  def self.run(argv = ARGV, output = $stdout)
    path = nil
    OptionParser.new do |parser|
      parser.banner = "Usage: jsonl_summary.rb [FILE]"
      parser.on("-h", "--help", "Show this help") do
        output.puts parser
        return 0
      end
    end.parse!(argv)

    path = argv.shift
    io = path.nil? || path == "-" ? $stdin : File.open(path)
    summary = summarize(io)
    io.close unless io == $stdin

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
  rescue Errno::ENOENT => e
    $stderr.puts "jsonl_summary: #{e.message}"
    2
  rescue JSON::ParserError => e
    $stderr.puts "jsonl_summary: invalid JSON: #{e.message}"
    2
  end
end

exit JsonlSummary.run if __FILE__ == $PROGRAM_NAME

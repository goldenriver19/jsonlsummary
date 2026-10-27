require "minitest/autorun"
require_relative "../jsonl_summary"

class TestJsonlSummary < Minitest::Test
  def test_summarizes_records
    io = StringIO.new(<<~JSONL)
      {"id":1,"score":10}
      {"id":2,"score":20}
    JSONL
    summary = JsonlSummary.summarize(io)

    assert_equal 2, summary.record_count
    assert_equal({ "id" => 2, "score" => 2 }, summary.key_counts)
    assert_equal({ count: 2, min: 1, max: 2, mean: 1.5, median: 1.5 }, summary.numeric_stats("id"))
    assert_equal({ count: 2, min: 10, max: 20, mean: 15.0, median: 15.0 }, summary.numeric_stats("score"))
  end

  def test_skips_blank_lines
    io = StringIO.new("{\"x\":5}\n\n")
    summary = JsonlSummary.summarize(io)
    assert_equal 1, summary.record_count
  end
end

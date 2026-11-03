require "minitest/autorun"
require "stringio"
require "tempfile"
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

  def test_empty_input
    summary = JsonlSummary.summarize(StringIO.new(""))
    assert_equal 0, summary.record_count
    assert_equal({}, summary.key_counts)
    assert_nil summary.numeric_stats("missing")
  end

  def test_ignores_non_numeric_and_boolean_fields
    io = StringIO.new("{\"flag\":true,\"value\":7}\n")
    summary = JsonlSummary.summarize(io)
    assert_equal ["value"], summary.numeric_values.keys
  end

  def test_ignores_non_finite_numeric_fields
    io = StringIO.new("{\"x\":1.0,\"y\":1e9999}\n")
    summary = JsonlSummary.summarize(io)
    assert_equal ["x"], summary.numeric_values.keys
  end

  def test_numeric_stats_does_not_create_missing_key
    io = StringIO.new("{\"x\":1}\n")
    summary = JsonlSummary.summarize(io)

    assert_equal ["x"], summary.numeric_values.keys
    assert_nil summary.numeric_stats("missing")
    assert_equal ["x"], summary.numeric_values.keys
  end

  def test_odd_median_and_invalid_json_line_number
    io = StringIO.new("{\"x\":1}\n{bad json}\n")
    error = assert_raises(JSON::ParserError) { JsonlSummary.summarize(io) }
    assert_match(/line 2:/, error.message)
  end

  def test_run_reports_missing_file
    status = JsonlSummary.run(["definitely-missing-jsonlsummary-file.json"], StringIO.new)
    assert_equal 2, status
  end

  def test_run_reports_invalid_json
    file = Tempfile.new("jsonl")
    begin
      file.write("{bad json}\n")
      file.close
      status = JsonlSummary.run([file.path], StringIO.new)
      assert_equal 2, status
    ensure
      file.unlink
    end
  end

  def test_run_reports_non_object_record
    file = Tempfile.new("jsonl")
    begin
      file.write("[1]\n")
      file.close
      status = JsonlSummary.run([file.path], StringIO.new)
      assert_equal 2, status
    ensure
      file.unlink
    end
  end

  def test_run_help_does_not_read_stdin
    output = StringIO.new
    status = JsonlSummary.run(["--help"], output)
    assert_equal 0, status
    assert_match(/Usage: jsonl_summary\.rb \[FILE\]/, output.string)
  end

  def test_run_rejects_extra_arguments
    status = JsonlSummary.run(["first", "second"], StringIO.new)
    assert_equal 2, status
  end
end

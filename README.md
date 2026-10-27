# jsonlsummary

A small Ruby command-line tool for summarizing JSON Lines (JSONL) files.

## Features

- Counts records
- Reports how often each key appears
- Computes count, minimum, maximum, mean, and median for numeric fields

## Requirements

- Ruby 3.0 or newer

## Usage

```sh
ruby jsonl_summary.rb data.jsonl
```

Read from standard input:

```sh
cat data.jsonl | ruby jsonl_summary.rb
```

Example input:

```jsonl
{"id":1,"score":10,"name":"a"}
{"id":2,"score":20}
```

Example output:

```text
records: 2
keys:
  id: 2
  name: 1
  score: 2
numeric:
  id: count=2 min=1 max=2 mean=1.5 median=1.5
  score: count=2 min=10 max=20 mean=15.0 median=15.0
```

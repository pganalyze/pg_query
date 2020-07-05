require 'pg_query/scan_output_pb'

class PgQuery
  class ScanError < ArgumentError
    attr_reader :location
    def initialize(message, source_file, source_line, location)
      super("#{message} (#{source_file}:#{source_line})")
      @location = location
    end
  end

  def self.scan(query)
    out, stderr = _raw_scan(query)

    result = PgQuery::ScanOutput.decode(out)

    warnings = []
    stderr.each_line do |line|
      next unless line[/^WARNING/]
      warnings << line.strip
    end

    [result, warnings]
  end
end
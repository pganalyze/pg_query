module PgQuery
  class SplitError < ArgumentError
    attr_reader :location

    def initialize(message, source_file, source_line, location)
      super("#{message} (#{source_file}:#{source_line})")
      @location = location
    end
  end

  def self.split_with_parser(query)
    result, stderr = _raw_split_with_parser(query)

    raise SplitError.new(stderr, 'stderr', '', '') unless stderr.empty?

    result.map do |location, len|
      query[location..location + len]
    end
  end
end

class PgQuery
  class ParseError < ArgumentError
    attr_reader :location
    def initialize(message, location)
      super(message)
      @location = location
    end
  end
end

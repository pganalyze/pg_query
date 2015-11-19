class PgQuery
  module DeparseHelper
    class VALUE
      def self.call(arg)
        arg.inspect.gsub("'", "''").tr('"', "'")
      end
    end
  end
end

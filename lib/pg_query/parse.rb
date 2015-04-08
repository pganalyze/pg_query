require 'json'

class PgQuery
  def self.parse(query)
    parsetree, stderr = _raw_parse(query)

    begin
      parsetree = JSON.parse(parsetree, max_nesting: 1000)
    rescue JSON::ParserError => e
      raise ParseError.new("Failed to parse JSON", -1)
    end

    warnings = []
    stderr.each_line do |line|
      next unless line[/^WARNING/]
      warnings << line.strip
    end

    PgQuery.new(query, parsetree, warnings)
  end

  attr_reader :query
  attr_reader :parsetree
  attr_reader :warnings
  def initialize(query, parsetree, warnings = [])
    @query = query
    @parsetree = parsetree
    @warnings = warnings
  end

  def tables
    load_tables_and_aliases! if @tables.nil?
    @tables
  end

  def aliases
    load_tables_and_aliases! if @aliases.nil?
    @aliases
  end

protected
  def load_tables_and_aliases!
    @tables = []
    @aliases = {}

    statements = @parsetree.dup
    from_clause_items = []
    where_clause_items = []

    loop do
      if statement = statements.shift
        case statement.keys[0]
        when "SELECT"
          if statement["SELECT"]["op"] == 0
            (statement["SELECT"]["fromClause"] || []).each do |item|
              if item["RANGESUBSELECT"]
                statements << item["RANGESUBSELECT"]["subquery"]
              else
                from_clause_items << item
              end
            end

            # CTEs
            if statement["SELECT"]["withClause"]
              statement["SELECT"]["withClause"]["WITHCLAUSE"]["ctes"].each do |item|
                statements << item["COMMONTABLEEXPR"]["ctequery"] if item["COMMONTABLEEXPR"]
              end
            end
          elsif statement["SELECT"]["op"] == 1
            statements << statement["SELECT"]["larg"] if statement["SELECT"]["larg"]
            statements << statement["SELECT"]["rarg"] if statement["SELECT"]["rarg"]
          end
        when "INSERT INTO", "UPDATE", "DELETE FROM", "VACUUM", "COPY", "ALTER TABLE", "CREATESTMT", "INDEXSTMT", "RULESTMT", "CREATETRIGSTMT"
          from_clause_items << statement.values[0]["relation"]
        when "VIEWSTMT"
          from_clause_items << statement["VIEWSTMT"]["view"]
          statements << statement["VIEWSTMT"]["query"]
        when "REFRESHMATVIEWSTMT"
          from_clause_items << statement["REFRESHMATVIEWSTMT"]["relation"]
        when "EXPLAIN"
          statements << statement["EXPLAIN"]["query"]
        when "CREATE TABLE AS"
          from_clause_items << statement["CREATE TABLE AS"]["into"]["INTOCLAUSE"]["rel"] rescue nil
        when "LOCK", "TRUNCATE"
          from_clause_items += statement.values[0]["relations"]
        when "GRANTSTMT"
          objects = statement["GRANTSTMT"]["objects"]
          case statement["GRANTSTMT"]["objtype"]
          when 0 # Column
            # FIXME
          when 1 # Table
            from_clause_items += objects
          when 2 # Sequence
            # FIXME
          end
        when "DROP"
          objects = statement["DROP"]["objects"]
          case statement["DROP"]["removeType"]
          when 26 # Table
            @tables += objects.map {|r| r.join('.') }
          when 23 # Rule
            @tables += objects.map {|r| r[0..-2].join('.') }
          when 28 # Trigger
            @tables += objects.map {|r| r[0..-2].join('.') }
          end
        end

        where_clause_items << statement.values[0]["whereClause"] if !statement.empty? && statement.values[0]["whereClause"]
      end

      # Find subselects in WHERE clause
      if next_item = where_clause_items.shift
        case next_item.keys[0]
        when /^AEXPR/, 'ANY'
          ["lexpr", "rexpr"].each do |side|
            next unless elem = next_item.values[0][side]
            if elem.is_a?(Array)
              where_clause_items += elem
            else
              where_clause_items << elem
            end
          end
        when 'SUBLINK'
          statements << next_item["SUBLINK"]["subselect"]
        end
      end

      break if where_clause_items.empty? && statements.empty?
    end

    loop do
      break unless next_item = from_clause_items.shift

      case next_item.keys[0]
      when "JOINEXPR"
        ["larg", "rarg"].each do |side|
          from_clause_items << next_item["JOINEXPR"][side]
        end
      when "ROW"
        from_clause_items += next_item["ROW"]["args"]
      when "RANGEVAR"
        rangevar = next_item["RANGEVAR"]
        table = [rangevar["schemaname"], rangevar["relname"]].compact.join('.')
        @tables << table
        @aliases[rangevar["alias"]["ALIAS"]["aliasname"]] = table if rangevar["alias"]
      end
    end

    @tables.uniq!
  end
end

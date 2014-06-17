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
          elsif statement["SELECT"]["op"] == 1
            statements << statement["SELECT"]["larg"] if statement["SELECT"]["larg"]
            statements << statement["SELECT"]["rarg"] if statement["SELECT"]["rarg"]
          end
        when "INSERT INTO", "UPDATE", "DELETE FROM", "VACUUM", "COPY", "ALTER TABLE"
          from_clause_items << statement.values[0]["relation"]
        when "EXPLAIN"
          statements << statement["EXPLAIN"]["query"]
        when "CREATE TABLE AS"
          from_clause_items << statement["CREATE TABLE AS"]["into"]["INTOCLAUSE"]["rel"] rescue nil
        when "LOCK"
          from_clause_items += statement["LOCK"]["relations"]
        when "DROP"
          object_type = statement["DROP"]["removeType"]
          @tables += statement["DROP"]["objects"].map {|r| r.join('.') } if object_type == 26 # Table
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
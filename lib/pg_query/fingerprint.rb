require 'digest'

module PgQuery
  # Faster fingerprint method that is implemented inside the native C library
  #
  # See ParserResult#fingerprint for the supported options
  def self.fingerprint(query, opts: FINGERPRINT_DEFAULT)
    _raw_fingerprint(query, opts)
  end

  class ParserResult
    # Fingerprint the parsed query
    #
    # Pass PgQuery::FINGERPRINT_* flags (combined with |) as opts to change how the
    # fingerprint is calculated, e.g. PgQuery::FINGERPRINT_RANGEVAR_PG17_COMPAT to
    # fingerprint relation references like pg_query 6.x and earlier (libpg_query 17)
    def fingerprint(opts: PgQuery::FINGERPRINT_DEFAULT)
      hash = FingerprintSubHash.new
      fingerprint_tree(hash, opts)
      fp = PgQuery.hash_xxh3_64(hash.parts.join, FINGERPRINT_VERSION)
      format('%016x', fp)
    end

    private

    FINGERPRINT_VERSION = 3

    class FingerprintSubHash
      attr_reader :parts

      def initialize
        @parts = []
      end

      def update(part)
        @parts << part
      end

      def flush_to(hash)
        parts.each do |part|
          hash.update part
        end
      end
    end

    def ignored_fingerprint_value?(val)
      [nil, 0, false, [], ''].include?(val)
    end

    def fingerprint_value(val, hash, opts, parent_node_name, parent_field_name, need_to_write_name) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/ParameterLists
      subhash = FingerprintSubHash.new

      if val.is_a?(Google::Protobuf::RepeatedField)
        # For lists that have exactly one untyped node, just output the parent field (if needed) and return
        if val.length == 1 && val[0].is_a?(Node) && val[0].node.nil?
          hash.update(parent_field_name) if need_to_write_name
          return
        end
        fingerprint_list(val, subhash, opts, parent_node_name, parent_field_name)
      elsif val.is_a?(List)
        fingerprint_list(val.items, subhash, opts, parent_node_name, parent_field_name)
      elsif val.is_a?(Google::Protobuf::MessageExts)
        fingerprint_node(val, subhash, opts, parent_node_name, parent_field_name)
      elsif !ignored_fingerprint_value?(val)
        subhash.update val.to_s
      end

      return if subhash.parts.empty?

      hash.update(parent_field_name) if need_to_write_name
      subhash.flush_to(hash)
    end

    def ignored_node_type?(node)
      [A_Const, Alias, ParamRef, SetToDefault, IntList, OidList].include?(node.class) ||
        (node.is_a?(TypeCast) && %i[a_const param_ref].include?(node.arg.node))
    end

    def node_protobuf_field_name_to_json_name(node_class, field)
      node_class.descriptor.find { |d| d.name == field.to_s }.json_name
    end

    def fingerprint_node(node, hash, opts, parent_node_name = nil, parent_field_name = nil) # rubocop:disable Metrics/CyclomaticComplexity
      return if ignored_node_type?(node)

      if node.is_a?(Node)
        node_val = node.inner
        unless node_val.nil? || ignored_node_type?(node_val)
          unless node_val.is_a?(List)
            postgres_node_name = node_protobuf_field_name_to_json_name(node.class, node.node)
            hash.update(postgres_node_name)
          end
          fingerprint_value(node_val, hash, opts, parent_node_name, parent_field_name, false)
        end
        return
      end

      postgres_node_name = node.class.name.split('::').last

      node.to_h.keys.sort.each do |field_name|
        val = node[field_name.to_s]

        postgres_field_name = node_protobuf_field_name_to_json_name(node.class, field_name)

        case postgres_field_name
        when 'location'
          next
        when 'arg_location'
          next if node.is_a?(DefElem)
        when 'payload', 'payload_location'
          next if node.is_a?(NotifyStmt)
        when 'conninfo_location'
          next if [CreateSubscriptionStmt, AlterSubscriptionStmt].include?(node.class)
        when 'list_start', 'list_end'
          next if [A_ArrayExpr, ArrayExpr].include?(node.class)
        when 'rexpr_list_start', 'rexpr_list_end'
          next if node.is_a?(A_Expr)
        when 'name'
          next if [PrepareStmt, ExecuteStmt, DeallocateStmt, FunctionParameter].include?(node.class)
          next if node.is_a?(ResTarget) && parent_node_name == 'SelectStmt' && parent_field_name == 'targetList'
        when 'gid', 'savepoint_name'
          next if node.is_a?(TransactionStmt)
        when 'options'
          next if node.is_a?(CreateFunctionStmt)
        when 'rolename'
          next if node.is_a?(RoleSpec)
        when 'role'
          next if node.is_a?(CreateRoleStmt)
        when 'newname', 'subname'
          next if node.is_a?(RenameStmt)
        when 'alias'
          if node.is_a?(RangeVar)
            fingerprint_value(val.aliasname, hash, opts, postgres_node_name, 'aliasname', true) if opts.nobits?(FINGERPRINT_RANGEVAR_IGNORE_ALIASES)
            next
          end
        when 'schemaname'
          next if node.is_a?(RangeVar) && opts.nobits?(FINGERPRINT_RANGEVAR_INCLUDE_SCHEMA) &&
                  range_var_in_dml_context?(parent_node_name, parent_field_name)
        when 'portalname'
          next if [DeclareCursorStmt, FetchStmt, ClosePortalStmt].include?(node.class)
        when 'conditionname'
          next if [ListenStmt, UnlistenStmt, NotifyStmt].include?(node.class)
        when 'args'
          next if node.is_a?(DoStmt)
        when 'relname'
          next if node.is_a?(RangeVar) && node.relpersistence == 't'
          # In SELECT/DML context the alias name replaces the relation name (matches Postgres 18+ query IDs)
          next if node.is_a?(RangeVar) && node.alias && opts.nobits?(FINGERPRINT_RANGEVAR_IGNORE_ALIASES) &&
                  range_var_in_dml_context?(parent_node_name, parent_field_name)
          # By default, 2+ consecutive digits are ignored (e.g. for date/number-suffixed partitions)
          if node.is_a?(RangeVar) && opts.nobits?(FINGERPRINT_FULL_RELNAME)
            fingerprint_value(val.gsub(/\d{2,}/, ''), hash, opts, postgres_node_name, postgres_field_name, true)
            next
          end
        when 'stmt_len', 'stmt_location'
          next if node.is_a?(RawStmt)
        when 'kind'
          if node.is_a?(A_Expr) && %i[AEXPR_OP_ANY AEXPR_IN].include?(val)
            fingerprint_value(:AEXPR_OP, hash, opts, postgres_node_name, postgres_field_name, true)
            next
          end
        # libpg_query still outputs `str` parts when print a string node. Here we override that to
        # the expected field name of `sval`.
        when 'sval', 'fval', 'bsval'
          postgres_field_name = 'str' if node.is_a?(String) || node.is_a?(BitString) || node.is_a?(Float)
        end

        fingerprint_value(val, hash, opts, postgres_node_name, postgres_field_name, true)
      end
    end

    def range_var_in_dml_context?(parent_node_name, parent_field_name)
      case parent_node_name
      when 'SelectStmt' then parent_field_name == 'fromClause'
      when 'InsertStmt' then parent_field_name == 'relation'
      when 'UpdateStmt' then %w[relation fromClause].include?(parent_field_name)
      when 'DeleteStmt' then %w[relation usingClause].include?(parent_field_name)
      when 'MergeStmt' then %w[relation sourceRelation].include?(parent_field_name)
      when 'JoinExpr', 'RangeTableSample', 'LockingClause' then true
      else false
      end
    end

    def fingerprint_list(values, hash, opts, parent_node_name, parent_field_name)
      if %w[fromClause targetList cols rexpr valuesLists args].include?(parent_field_name)
        values_subhashes = values.map do |val|
          subhash = FingerprintSubHash.new
          fingerprint_value(val, subhash, opts, parent_node_name, parent_field_name, false)
          subhash
        end

        values_subhashes.uniq!(&:parts)
        values_subhashes.sort_by! { |s| PgQuery.hash_xxh3_64(s.parts.join, FINGERPRINT_VERSION) }

        values_subhashes.each do |subhash|
          subhash.flush_to(hash)
        end
      else
        values.each do |val|
          fingerprint_value(val, hash, opts, parent_node_name, parent_field_name, false)
        end
      end
    end

    def fingerprint_tree(hash, opts = PgQuery::FINGERPRINT_DEFAULT)
      @tree.stmts.each do |node|
        hash.update 'RawStmt'
        fingerprint_node(node, hash, opts)
      end
    end
  end
end

require 'digest'

class PgQuery
  def fingerprint
    hash = Digest::SHA1.new
    fingerprint_tree(hash)
    format('%02x', FINGERPRINT_VERSION) + hash.hexdigest
  end

  private

  FINGERPRINT_VERSION = 1

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

  def fingerprint_value(val, hash, field_name, need_to_write_name)
    return if ignored_fingerprint_value?(val)

    subhash = FingerprintSubHash.new

    if val.is_a?(Hash)
      fingerprint_node(val, subhash, field_name)
    elsif val.is_a?(Array)
      fingerprint_list(val, subhash, field_name)
    else
      subhash.update val.to_s
    end

    return if subhash.parts.empty?

    hash.update(field_name) if need_to_write_name
    subhash.flush_to(hash)
  end

  def fingerprint_node(node, hash, parent_field_name = nil) # rubocop:disable Metrics/CyclomaticComplexity
    node_name = node.keys.first
    return if [A_CONST, ALIAS, PARAM_REF, SET_TO_DEFAULT, INT_LIST, OID_LIST, NULL].include?(node_name)

    hash.update node_name

    node.values.first.sort_by { |k, _| k }.each do |field_name, val|
      next if ignored_fingerprint_value?(val)

      case field_name
      when 'location'
        next
      when 'name'
        next if node_name == RES_TARGET && parent_field_name == TARGET_LIST_FIELD
        next if [PREPARE_STMT, EXECUTE_STMT, DEALLOCATE_STMT].include?(node_name)
      when 'gid'
        next if node_name == TRANSACTION_STMT
      when 'options'
        next if node_name == TRANSACTION_STMT
      end

      fingerprint_value(val, hash, field_name, true)
    end
  end

  def fingerprint_list(values, hash, parent_field_name)
    if [FROM_CLAUSE_FIELD, TARGET_LIST_FIELD, COLS_FIELD, REXPR_FIELD].include?(parent_field_name)
      values_subhashes = values.map do |val|
        subhash = FingerprintSubHash.new
        fingerprint_value(val, subhash, parent_field_name, false)
        subhash
      end

      values_subhashes.uniq!(&:parts)
      values_subhashes.sort_by!(&:parts)

      values_subhashes.each do |subhash|
        subhash.flush_to(hash)
      end
    else
      values.each do |val|
        fingerprint_value(val, hash, parent_field_name, false)
      end
    end
  end

  def fingerprint_tree(hash)
    @tree.each do |node|
      fingerprint_node(node, hash)
    end
  end
end

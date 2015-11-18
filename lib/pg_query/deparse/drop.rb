# AUTO GENERATED - DO NOT EDIT

# rubocop:disable all
class PgQuery::Deparse::DROP
  def self.call(node)
    result = []

    result << 'DROP'

    if node['removeType'] == 26
      result << 'TABLE'
    end

    if node['concurrent']
      result << 'CONCURRENTLY'
    end

    if node['missing_ok']
      result << 'IF EXISTS'
    end

    result << node['objects'].join(', ')

    if node['behavior'] == 1
      result << 'CASCADE'
    end

    return result.join(' ')
  end
end

class PgQuery
  def param_refs # rubocop:disable Metrics/CyclomaticComplexity
    results = []

    treewalker! parsetree do |_, _, v|
      next unless v.is_a?(Hash)

      if v['PARAMREF']
        results << { 'location' => v['PARAMREF']['location'],
                     'length' => param_ref_length(v['PARAMREF']) }
      elsif v['TYPECAST']
        next unless v['TYPECAST']['arg'] && v['TYPECAST']['typeName']

        p = v['TYPECAST']['arg'].delete('PARAMREF')
        t = v['TYPECAST']['typeName'].delete('TYPENAME')
        next unless p && t

        location = p['location']
        typeloc  = t['location']
        typename = t['names'].join('.')
        length   = param_ref_length(p)

        if typeloc < location
          length += location - typeloc
          location = typeloc
        end

        results << { 'location' => location, 'length' => length, 'typename' => typename }
      end
    end

    results.sort_by! { |r| r['location'] }
    results
  end

  private

  def param_ref_length(paramref_node)
    if paramref_node['number'] == 0
      1 # Actually a ? replacement character
    else
      ('$' + paramref_node['number'].to_s).size
    end
  end
end

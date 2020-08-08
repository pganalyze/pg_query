class PgQuery::ParseResult
  def param_refs # rubocop:disable Metrics/CyclomaticComplexity
    results = []

    treewalker! @tree do |_, _, v|
      next unless v.is_a?(Hash)

      if v[PARAM_REF]
        results << { 'location' => v[PARAM_REF]['location'],
                     'length' => param_ref_length(v[PARAM_REF]) }
      elsif v[TYPE_CAST]
        next unless v[TYPE_CAST]['arg'] && v[TYPE_CAST]['typeName']

        p = v[TYPE_CAST]['arg'].delete(PARAM_REF)
        t = v[TYPE_CAST]['typeName'].delete(TYPE_NAME)
        next unless p && t

        location = p['location']
        typeloc  = t['location']
        typename = t['names']
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
    if paramref_node['number'] == 0 # rubocop:disable Style/NumericPredicate
      1 # Actually a ? replacement character
    else
      ('$' + paramref_node['number'].to_s).size
    end
  end
end

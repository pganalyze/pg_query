class PgQuery
  def param_refs # rubocop:disable Metrics/CyclomaticComplexity
    results = []

    treewalker! parsetree do |_, _, v|
      next unless v.is_a?(Hash)

      if v['ParamRef']
        results << { 'location' => v['ParamRef']['location'],
                     'length' => param_ref_length(v['ParamRef']) }
      elsif v['TypeCast']
        next unless v['TypeCast']['arg'] && v['TypeCast']['typeName']

        p = v['TypeCast']['arg'].delete('ParamRef')
        t = v['TypeCast']['typeName'].delete('TypeName')
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
    if paramref_node['number'] == 0
      1 # Actually a ? replacement character
    else
      ('$' + paramref_node['number'].to_s).size
    end
  end
end

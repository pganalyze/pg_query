require 'json'

class PgQueryparser
  def self.parse(input)
    str = _raw_parse(input)
    str = parsetree_to_json(str)
    JSON.parse(str, max_nesting: 1000)
  end

protected
  def self.parsetree_to_json(str)
    str.strip!
    control_chars = '(){}: '
    location = nil # :hashname, :key, :value
    structure_stack = [] # :hash, :array (when delimiter opens we push, when delimiter closes we pop)
    open_string = false
    escaped_string = false
    next_char_is_escaped = false
    double_hash_close_in = 0 # This is used to ask for an additional closing delimiter (added when x = 1 and we reach a closing delimiter)
    out = ""
  
    i = 0
    loop do
      break if i > str.size-1
    
      c = str[i]
      last_location = location
      char_is_escaped = next_char_is_escaped
      next_char_is_escaped = false
      if control_chars.include?(c) && !char_is_escaped && (!open_string || !escaped_string)
        # Space is not always a control character, skip in those cases
        if c == ' ' && last_location == :hashname && str[i+1] != ':'
          out += c
          i += 1
          next
        end
        
        # Keep empty nodes as empty hashes (e.g. nodes that can't be output)
        if c == '{' && str[i+1] == '}'
          out += "{}"
          out += ", " if i+2 < str.size && !'})'.include?(str[i+2])
          i += 2 # Skip {}
          next
        end
      
        location = nil # All control characters reset location
      
        # This should never happen, but if it does, catch it
        if open_string
          out += '"' unless escaped_string
          open_string = false
          escaped_string = false
        end
      
        # Write out JSON control characters
        if last_location == :hashname
          out += ': {'
        elsif last_location == :key
          out += ': '
        end
      
        case c
        when '('
          out += '['
        when ')'
          out += ']'
        when '{'
          out += '{'
        when '}'
          out += '}}'
        when ':'
          # No JSON equivalent
        end
        
        # Handle double hash closes (required for out-of-place nodes like ANY)
        case c
        when '{'  
          if double_hash_close_in > 0
            double_hash_close_in += 1
          end
        when '}'
          if double_hash_close_in == 1
            out += '}}'
            double_hash_close_in = 0
          elsif double_hash_close_in > 1
            double_hash_close_in -= 1
          end
        end
      
        # Write out delimiter if needed
        if (last_location == :value || '})'.include?(c)) && i+1 < str.size && !'})'.include?(str[i+1])
          out += ', '
        end
      
        # Determine new location
        case c
        when '{'
          structure_stack << :hash
          location = :hashname
        when '('
          structure_stack << :array
          location = :value if !control_chars.include?(str[i+1])
        when '}', ')'
          structure_stack.pop
        when ':'
          location = :key
        when ' '
          location = :value if [:value, :key].include?(last_location) && !control_chars.include?(str[i+1])
        end
      else
        if char_is_escaped
          case c
          when '"'
            out += "\\\""
          when '\\'
            out += "\\\\"
          else
            out += c
          end
        elsif str[i] == '<' && str[i+1] == '>' && control_chars.include?(str[i+2])
          # Make <> into null values
          i += 1
          out += "null"
        elsif c == '\\'
          next_char_is_escaped = true # For next round
          # Ignore all other cases
        elsif c[/[A-Z]/] && !open_string && last_location != :value && last_location != :hashname && structure_stack.last == :hash
          # We were not expecting a node name here, but this can happen (e.g. with ANY), try to construct into valid expression
          location = :hashname
          double_hash_close_in = 1
          open_string = true
          out += '"lexpr": {"'
          out += c
        elsif control_chars.include?(str[i-1]) && !open_string && !'0123456789'.include?(c)
          open_string = true
          escaped_string = true if c == '"'
          out += '"' unless escaped_string
          out += c
          c = nil # To avoid close string taking care of us...
        else
          out += c
        end
      
        # Close string if next element is control character
        if open_string && !char_is_escaped && c != '\\' &&
           ((last_location == :hashname && ((str[i+1] == '}') || (str[i+1] == ' ' && str[i+2] == ':') || (str[i+1] == ' ' && str[i+2] == ' ' && str[i+3] == ':'))) ||
            (last_location != :hashname && !escaped_string && control_chars.include?(str[i+1])) || 
            (escaped_string && c == '"'))
          out += '"' unless escaped_string
          open_string = false
          escaped_string = false
        end
      end

      i += 1
    end
    out
  end
end
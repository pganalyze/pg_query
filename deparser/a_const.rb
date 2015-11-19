define_deparse 'A_CONST' do
  result { deparse_helper 'value', [:node, :val] }
end

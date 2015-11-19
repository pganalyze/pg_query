define_deparse 'A_INDICES' do
  result { fmt('[%s]') { deparse [:node, :uidx] } }
end

require 'spec_helper'

describe PgQuery, '.treewalker' do
  it 'walks nodes contained in repeated fields' do
    locations = []
    described_class.parse("SELECT to_timestamp($1)").walk! do |_, _, _, location|
      locations << location
    end
    expect(locations).to match_array [
      [:stmts],
      [:stmts, 0],
      [:stmts, 0, :stmt],
      [:stmts, 0, :stmt, :select_stmt],
      [:stmts, 0, :stmt, :select_stmt, :distinct_clause],
      [:stmts, 0, :stmt, :select_stmt, :target_list],
      [:stmts, 0, :stmt, :select_stmt, :from_clause],
      [:stmts, 0, :stmt, :select_stmt, :group_clause],
      [:stmts, 0, :stmt, :select_stmt, :window_clause],
      [:stmts, 0, :stmt, :select_stmt, :values_lists],
      [:stmts, 0, :stmt, :select_stmt, :sort_clause],
      [:stmts, 0, :stmt, :select_stmt, :locking_clause],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :indirection],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :funcname],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :args],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :agg_order],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :funcname, 0],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :args, 0],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :funcname, 0, :string],
      [:stmts, 0, :stmt, :select_stmt, :target_list, 0, :res_target, :val, :func_call, :args, 0, :param_ref]
    ]
  end
end

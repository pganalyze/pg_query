require 'spec_helper'

describe PgQuery do
  describe '#walk!' do
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

    it 'allows recursively replacing nodes' do
      query = PgQuery.parse("SELECT * FROM tbl WHERE col::text = ANY(((ARRAY[$39, $40])::varchar[])::text[])")
      query.walk! do |node|
        next unless node.is_a?(PgQuery::Node)
        # Keep removing type casts until we hit a different class
        node.inner = node.type_cast.arg.inner while node.node == :type_cast
      end
      expect(query.deparse).to eq 'SELECT * FROM tbl WHERE col = ANY(ARRAY[$39, $40])'
    end
  end

  describe '#walk_subtree!' do
    it 'yields the starting subtree itself first' do
      query = described_class.parse("SELECT 1")
      select_stmt = query.tree.stmts[0].stmt.select_stmt
      yielded = []
      query.walk_subtree!(select_stmt) { |node| yielded << node }
      expect(yielded.first).to be(select_stmt)
    end

    it 'yields nested messages and repeated fields under the subtree' do
      query = described_class.parse("SELECT 1, 2")
      select_stmt = query.tree.stmts[0].stmt.select_stmt
      classes = []
      query.walk_subtree!(select_stmt) { |node| classes << node.class }
      expect(classes).to include(PgQuery::SelectStmt, Google::Protobuf::RepeatedField, PgQuery::ResTarget, PgQuery::Node, PgQuery::A_Const, PgQuery::Integer)
    end

    it 'stops descending when the block returns :skip' do
      query = described_class.parse("SELECT foo(1) FROM tbl")
      yielded = []
      query.walk_subtree!(query.tree) do |node|
        yielded << node
        node.is_a?(PgQuery::FuncCall) ? :skip : nil
      end
      func_call = yielded.find { |n| n.is_a?(PgQuery::FuncCall) }
      expect(func_call).not_to be_nil
      # Nothing nested inside the FuncCall (e.g. its funcname/args) should have been yielded
      expect(yielded.any? { |n| n.equal?(func_call.funcname) }).to be false
      expect(yielded.any? { |n| n.equal?(func_call.args) }).to be false
    end

    it 'does not yield anything when the root is skipped' do
      query = described_class.parse("SELECT 1")
      yielded = []
      query.walk_subtree!(query.tree) do |node|
        yielded << node
        :skip
      end
      expect(yielded).to eq [query.tree]
    end
  end
end

require 'spec_helper'

describe PgQuery do
  def parse_expr(expr)
    query = described_class.parse("SELECT " + expr + " FROM x")
    expect(query.tree).not_to be_nil
    expr = query.tree.stmts.first.stmt.select_stmt.target_list[0].res_target.val
    expect(expr.node).to eq :a_expr
    expr.a_expr
  end

  it "parses a normalized query" do
    query = described_class.parse("SELECT $1 FROM x")
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.from(
          PgQuery::SelectStmt.new(
            target_list: [
              PgQuery::Node.from(
                PgQuery::ResTarget.new(
                  val: PgQuery::Node.from(
                    PgQuery::ParamRef.new(number: 1, location: 7)
                  ),
                  location: 7
                )
              )
            ],
            from_clause: [
              PgQuery::Node.from(PgQuery::RangeVar.new(relname: "x", inh: true, relpersistence: "p", location: 15))
            ],
            limit_option: :LIMIT_OPTION_DEFAULT,
            op: :SETOP_NONE
          )
        )
      )
    )
  end

  it 'keep locations correct' do
    query = described_class.parse("SELECT $1, 123")
    targetlist = query.tree.stmts.first.stmt.select_stmt.target_list
    expect(targetlist[0].res_target.location).to eq 7
    expect(targetlist[1].res_target.location).to eq 11
  end

  # This is a pg_query patch to support param refs in more places
  context 'additional param ref support' do
    it "parses INTERVAL $1" do
      query = described_class.parse("SELECT INTERVAL $1")
      targetlist = query.tree.stmts.first.stmt.select_stmt.target_list
      expect(targetlist[0].res_target.val).to eq(
        PgQuery::Node.from(
          PgQuery::TypeCast.new(
            arg: PgQuery::Node.from(
              PgQuery::ParamRef.new(number: 1, location: 16)
            ),
            type_name: PgQuery::TypeName.new(
              names: [
                PgQuery::Node.from_string("pg_catalog"),
                PgQuery::Node.from_string("interval")
              ],
              typemod: -1,
              location: 7
            ),
            location: -1
          )
        )
      )
    end

    it "parses INTERVAL $1 hour" do
      query = described_class.parse("SELECT INTERVAL $1 hour")
      expr = query.tree.stmts.first.stmt.select_stmt.target_list[0].res_target.val
      expect(expr).to eq(
        PgQuery::Node.from(
          PgQuery::TypeCast.new(
            arg: PgQuery::Node.from(
              PgQuery::ParamRef.new(number: 1, location: 16)
            ),
            type_name: PgQuery::TypeName.new(
              names: [
                PgQuery::Node.from_string("pg_catalog"),
                PgQuery::Node.from_string("interval")
              ],
              typmods: [
                PgQuery::Node.from(
                  PgQuery::A_Const.new(
                    ival: PgQuery::Integer.new(ival: 1024),
                    isnull: false,
                    location: 19
                  )
                )
              ],
              typemod: -1,
              location: 7
            ),
            location: -1
          )
        )
      )
    end

    # Note how Postgres does not replace the integer value here
    it "parses INTERVAL (2) $2" do
      query = described_class.parse("SELECT INTERVAL (2) $2")
      expect(query.tree).not_to be_nil
    end

    # Note how Postgres does not replace the integer value here
    it "parses cast($1 as varchar(2))" do
      query = described_class.parse("SELECT cast($1 as varchar(2))")
      expect(query.tree).not_to be_nil
    end

    it "parses substituted pseudo keywords in extract()" do
      query = described_class.parse("SELECT extract($1 from NOW())")
      expr = query.tree.stmts.first.stmt.select_stmt.target_list[0].res_target.val
      expect(expr).to eq(
        PgQuery::Node.from(
          PgQuery::FuncCall.new(
            funcname: [PgQuery::Node.from_string('pg_catalog'), PgQuery::Node.from_string('extract')],
            funcformat: :COERCE_SQL_SYNTAX,
            args: [
              PgQuery::Node.from(PgQuery::ParamRef.new(number: 1, location: 15)),
              PgQuery::Node.from(
                PgQuery::FuncCall.new(
                  funcname: [PgQuery::Node.from_string('now')],
                  funcformat: :COERCE_EXPLICIT_CALL,
                  location: 23
                )
              )
            ],
            location: 7
          )
        )
      )
    end

    it "parses SET x = $1" do
      query = described_class.parse("SET statement_timeout = $1")
      expect(query.tree).not_to be_nil
    end

    it "parses SET x=$1" do
      query = described_class.parse("SET statement_timeout=$1")
      expect(query.tree).not_to be_nil
    end

    it "parses SET TIME ZONE $1" do
      query = described_class.parse("SET TIME ZONE $1")
      expect(query.tree).not_to be_nil
    end

    it "parses SET SCHEMA $1" do
      query = described_class.parse("SET SCHEMA $1")
      expect(query.tree).not_to be_nil
    end

    it "parses SET ROLE $1" do
      query = described_class.parse("SET ROLE $1")
      expect(query.tree).not_to be_nil
    end

    it "parses SET SESSION AUTHORIZATION $1" do
      query = described_class.parse("SET SESSION AUTHORIZATION $1")
      expect(query.tree).not_to be_nil
    end
  end
end

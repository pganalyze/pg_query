require 'spec_helper'

describe PgQuery, '.parse' do
  it "parses a simple query" do
    query = described_class.parse("SELECT 1")
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          select_stmt: PgQuery::SelectStmt.new(
            target_list: [
              PgQuery::Node.new(
                res_target: PgQuery::ResTarget.new(
                  val: PgQuery::Node.new(
                    a_const: PgQuery::A_Const.new(
                      val: PgQuery::Node.new(
                        integer: PgQuery::Integer.new(
                          ival: 1
                        )
                      ),
                      location: 7
                    )
                  ),
                  location: 7
                )
              )
            ],
            limit_option: :LIMIT_OPTION_DEFAULT, # TODO: This is cumbersome, we should have LIMIT_OPTION_DEFAULT be the zero state here
            op: :SETOP_NONE # TODO: This should be the default
          )
        )
      )
    )
    expect(JSON.parse(PgQuery::ParseResult.encode_json(query.tree))).to eq(
      "version" => PgQuery::PG_VERSION_NUM,
      "stmts" => [
        {
          "stmt" => {
            "selectStmt" => {
              "limitOption" => "LIMIT_OPTION_DEFAULT",
              "op" => "SETOP_NONE",
              "targetList" => [
                {
                  "resTarget" => {
                    "location"=>7,
                    "val" => {
                      "aConst" => {
                        "location" => 7,
                        "val" => {
                          "integer" => {
                            "ival" => 1
                          }
                        }
                      }
                    }
                  }
                }
              ]
            }
          }
        }
      ]
    )
  end

  it "handles errors" do
    expect { described_class.parse("SELECT 'ERR") }.to(raise_error do |error|
      expect(error).to be_a(PgQuery::ParseError)
      expect(error.message).to eq "unterminated quoted string at or near \"'ERR\" (scan.l:1234)"
      expect(error.location).to eq 8 # 8th character in query string
    end)
  end

  it 'returns JSON error due to too much nesting' do
    query_text = 'SELECT a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(a(b))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))'
    expect { described_class.parse(query_text) }.to(raise_error do |error|
      expect(error).to be_a(PgQuery::ParseError)
      expect(error.message).to start_with 'Failed to parse tree'
    end)
  end

  it "parses real queries" do
    query = described_class.parse("SELECT memory_total_bytes, memory_free_bytes, memory_pagecache_bytes, memory_buffers_bytes, memory_applications_bytes, (memory_swap_total_bytes - memory_swap_free_bytes) AS swap, date_part($0, s.collected_at) AS collected_at FROM snapshots s JOIN system_snapshots ON (snapshot_id = s.id) WHERE s.database_id = $0 AND s.collected_at BETWEEN $0 AND $0 ORDER BY collected_at")
    expect(query.tree).not_to be_nil
    expect(query.tables).to eq ['snapshots', 'system_snapshots']
    expect(query.select_tables).to eq ['snapshots', 'system_snapshots']
  end

  it "parses empty queries" do
    query = described_class.parse("-- nothing")
    expect(query.tree).to eq PgQuery::ParseResult.new(version: PgQuery::PG_VERSION_NUM, stmts: [])
    expect(query.tables).to eq []
    expect(query.warnings).to be_empty
  end

  it "parses floats with leading dot" do
    q = described_class.parse("SELECT .1")
    expr = q.tree.stmts[0].stmt.select_stmt.target_list[0].res_target.val
    expect(expr).to eq(PgQuery::Node.new(a_const: PgQuery::A_Const.new(val: PgQuery::Node.new(float: PgQuery::Float.new(str: '.1')), location: 7)))
  end

  it "parses floats with trailing dot" do
    q = described_class.parse("SELECT 1.")
    expr = q.tree.stmts[0].stmt.select_stmt.target_list[0].res_target.val
    expect(expr).to eq(PgQuery::Node.new(a_const: PgQuery::A_Const.new(val: PgQuery::Node.new(float: PgQuery::Float.new(str: '1.')), location: 7)))
  end

  it 'parses bit strings (binary notation)' do
    q = described_class.parse("SELECT B'0101'")
    expr = q.tree.stmts[0].stmt.select_stmt.target_list[0].res_target.val
    expect(expr).to eq(PgQuery::Node.new(a_const: PgQuery::A_Const.new(val: PgQuery::Node.new(bit_string: PgQuery::BitString.new(str: 'b0101')), location: 7)))
  end

  it 'parses bit strings (hex notation)' do
    q = described_class.parse("SELECT X'EFFF'")
    expr = q.tree.stmts[0].stmt.select_stmt.target_list[0].res_target.val
    expect(expr).to eq(PgQuery::Node.new(a_const: PgQuery::A_Const.new(val: PgQuery::Node.new(bit_string: PgQuery::BitString.new(str: 'xEFFF')), location: 7)))
  end

  it "parses ALTER TABLE" do
    query = described_class.parse("ALTER TABLE test ADD PRIMARY KEY (gid)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          alter_table_stmt: PgQuery::AlterTableStmt.new(
            relation: PgQuery::RangeVar.new(relname: 'test', inh: true, relpersistence: 'p', location: 12),
            cmds: [
              PgQuery::Node.new(
                alter_table_cmd: PgQuery::AlterTableCmd.new(
                  subtype: :AT_AddConstraint,
                  def: PgQuery::Node.new(
                    constraint: PgQuery::Constraint.new(
                      contype: :CONSTR_PRIMARY,
                      location: 21,
                      keys: [PgQuery::Node.new(string: PgQuery::String.new(str: 'gid'))]
                    )
                  ),
                  behavior: :DROP_RESTRICT
                )
              )
            ],
            relkind: :OBJECT_TABLE
          )
        )
      )
    )
  end

  it "parses SET" do
    query = described_class.parse("SET statement_timeout=0")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          variable_set_stmt: PgQuery::VariableSetStmt.new(
            kind: :VAR_SET_VALUE,
            name: 'statement_timeout',
            args: [
              PgQuery::Node.new(
                a_const: PgQuery::A_Const.new(
                  val: PgQuery::Node.new(
                    integer: PgQuery::Integer.new(ival: 0)
                  ),
                  location: 22
                )
              )
            ]
          )
        )
      )
    )
  end

  it "parses SHOW" do
    query = described_class.parse("SHOW work_mem")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          variable_show_stmt: PgQuery::VariableShowStmt.new(
            name: 'work_mem'
          )
        )
      )
    )
  end

  it "parses COPY" do
    query = described_class.parse("COPY test (id) TO stdout")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          copy_stmt: PgQuery::CopyStmt.new(
            relation: PgQuery::RangeVar.new(
              relname: 'test',
              inh: true,
              relpersistence: 'p',
              location: 5
            ),
            attlist: [
              PgQuery::Node.new(string: PgQuery::String.new(str: 'id'))
            ]
          )
        )
      )
    )
  end

  it "parses DROP TABLE" do
    query = described_class.parse("drop table abc.test123 cascade")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc.test123']
    expect(query.ddl_tables).to eq ['abc.test123']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(list: PgQuery::List.new(
                items: [
                  PgQuery::Node.new(string: PgQuery::String.new(str: 'abc')),
                  PgQuery::Node.new(string: PgQuery::String.new(str: 'test123'))
                ]
              ))
            ],
            remove_type: :OBJECT_TABLE,
            behavior: :DROP_CASCADE
          )
        )
      )
    )
  end

  it "parses COMMIT" do
    query = described_class.parse("COMMIT")
    expect(query.warnings).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          transaction_stmt: PgQuery::TransactionStmt.new(
            kind: :TRANS_STMT_COMMIT
          )
        )
      )
    )
  end

  it "parses CHECKPOINT" do
    query = described_class.parse("CHECKPOINT")
    expect(query.warnings).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          check_point_stmt: PgQuery::CheckPointStmt.new
        )
      )
    )
  end

  it "parses VACUUM" do
    query = described_class.parse("VACUUM my_table")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['my_table']
    expect(query.ddl_tables).to eq ['my_table']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          vacuum_stmt: PgQuery::VacuumStmt.new(
            is_vacuumcmd: true,
            rels: [
              PgQuery::Node.new(
                vacuum_relation: PgQuery::VacuumRelation.new(
                  relation: PgQuery::RangeVar.new(
                    relname: 'my_table',
                    inh: true,
                    relpersistence: 'p',
                    location: 7
                  )
                )
              )
            ]
          )
        )
      )
    )
  end

  it "parses EXPLAIN" do
    query = described_class.parse("EXPLAIN DELETE FROM test")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          explain_stmt: PgQuery::ExplainStmt.new(
            query: PgQuery::Node.new(
              delete_stmt: PgQuery::DeleteStmt.new(
                relation: PgQuery::RangeVar.new(
                  relname: 'test',
                  inh: true,
                  relpersistence: 'p',
                  location: 20
                )
              )
            )
          )
        )
      )
    )
  end

  it "parses SELECT INTO" do
    query = described_class.parse("CREATE TEMP TABLE test AS SELECT 1")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_table_as_stmt: PgQuery::CreateTableAsStmt.new(
            query: PgQuery::Node.new(
              select_stmt: PgQuery::SelectStmt.new(
                target_list: [
                  PgQuery::Node.new(
                    res_target: PgQuery::ResTarget.new(
                      val: PgQuery::Node.new(
                        a_const: PgQuery::A_Const.new(
                          val: PgQuery::Node.new(
                            integer: PgQuery::Integer.new(ival: 1)
                          ),
                          location: 33
                        )
                      ),
                      location: 33
                    )
                  )
                ],
                limit_option: :LIMIT_OPTION_DEFAULT,
                op: :SETOP_NONE
              )
            ),
            into: PgQuery::IntoClause.new(
              rel: PgQuery::RangeVar.new(
                relname: 'test',
                inh: true,
                relpersistence: 't',
                location: 18
              ),
              on_commit: :ONCOMMIT_NOOP
            ),
            relkind: :OBJECT_TABLE
          )
        )
      )
    )
  end

  it "parses LOCK" do
    query = described_class.parse("LOCK TABLE public.schema_migrations IN ACCESS SHARE MODE")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['public.schema_migrations']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          lock_stmt: PgQuery::LockStmt.new(
            relations: [
              PgQuery::Node.new(
                range_var: PgQuery::RangeVar.new(
                  schemaname: 'public',
                  relname: 'schema_migrations',
                  inh: true,
                  relpersistence: 'p',
                  location: 11
                )
              )
            ],
            mode: PgQuery::LOCK_MODE_ACCESS_SHARE_LOCK
          )
        )
      )
    )
  end

  it 'parses CREATE TABLE' do
    query = described_class.parse('CREATE TABLE test (a int4)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_stmt: PgQuery::CreateStmt.new(
            relation: PgQuery::RangeVar.new(
              relname: 'test',
              inh: true,
              relpersistence: 'p',
              location: 13
            ),
            table_elts: [
              PgQuery::Node.new(
                column_def: PgQuery::ColumnDef.new(
                  colname: 'a',
                  type_name: PgQuery::TypeName.new(
                    names: [
                      PgQuery::Node.new(string: PgQuery::String.new(str: 'int4'))
                    ],
                    typemod: -1,
                    location: 21
                  ),
                  is_local: true,
                  location: 19
                )
              )
            ],
            oncommit: :ONCOMMIT_NOOP
          )
        )
      )
    )
  end

  it 'fails to parse CREATE TABLE WITH OIDS' do
    expect { described_class.parse("CREATE TABLE test (a int4) WITH OIDS") }.to(raise_error do |error|
      expect(error).to be_a(PgQuery::ParseError)
      expect(error.message).to eq "syntax error at or near \"OIDS\" (scan.l:1234)"
      expect(error.location).to eq 33 # 33rd character in query string
    end)
  end

  it 'parses CREATE INDEX' do
    query = described_class.parse('CREATE INDEX testidx ON test USING gist (a)')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['test']
    expect(query.ddl_tables).to eq ['test']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          index_stmt: PgQuery::IndexStmt.new(
            idxname: 'testidx',
            relation: PgQuery::RangeVar.new(
              relname: 'test',
              inh: true,
              relpersistence: 'p',
              location: 24
            ),
            access_method: 'gist',
            index_params: [
              PgQuery::Node.new(
                index_elem: PgQuery::IndexElem.new(
                  name: 'a',
                  ordering: :SORTBY_DEFAULT,
                  nulls_ordering: :SORTBY_NULLS_DEFAULT
                )
              )
            ]
          )
        )
      )
    )
  end

  it 'parses CREATE SCHEMA' do
    query = described_class.parse('CREATE SCHEMA IF NOT EXISTS test AUTHORIZATION joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_schema_stmt: PgQuery::CreateSchemaStmt.new(
            schemaname: 'test',
            authrole: PgQuery::RoleSpec.new(roletype: :ROLESPEC_CSTRING, rolename: 'joe', location: 47),
            if_not_exists: true
          )
        )
      )
    )
  end

  it 'parses CREATE VIEW' do
    query = described_class.parse('CREATE VIEW myview AS SELECT * FROM mytab')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview', 'mytab']
    expect(query.ddl_tables).to eq ['myview']
    expect(query.select_tables).to eq ['mytab']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          view_stmt: PgQuery::ViewStmt.new(
            view: PgQuery::RangeVar.new(
              relname: 'myview',
              inh: true,
              relpersistence: 'p',
              location: 12
            ),
            query: PgQuery::Node.new(
              select_stmt: PgQuery::SelectStmt.new(
                target_list: [
                  PgQuery::Node.new(
                    res_target: PgQuery::ResTarget.new(
                      val: PgQuery::Node.new(
                        column_ref: PgQuery::ColumnRef.new(
                          fields: [
                            PgQuery::Node.new(a_star: PgQuery::A_Star.new)
                          ],
                          location: 29
                        )
                      ),
                      location: 29
                    )
                  )
                ],
                from_clause: [
                  PgQuery::Node.new(
                    range_var: PgQuery::RangeVar.new(
                      relname: 'mytab',
                      inh: true,
                      relpersistence: 'p',
                      location: 36
                    )
                  )
                ],
                limit_option: :LIMIT_OPTION_DEFAULT,
                op: :SETOP_NONE
              )
            ),
            with_check_option: :NO_CHECK_OPTION
          )
        )
      )
    )
  end

  it 'parses REFRESH MATERIALIZED VIEW' do
    query = described_class.parse('REFRESH MATERIALIZED VIEW myview')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['myview']
    expect(query.ddl_tables).to eq ['myview']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          refresh_mat_view_stmt: PgQuery::RefreshMatViewStmt.new(
            relation: PgQuery::RangeVar.new(
              relname: 'myview',
              inh: true,
              relpersistence: 'p',
              location: 26
            )
          )
        )
      )
    )
  end

  it 'parses CREATE RULE' do
    query = described_class.parse('CREATE RULE shoe_ins_protect AS ON INSERT TO shoe
                           DO INSTEAD NOTHING')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['shoe']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          rule_stmt: PgQuery::RuleStmt.new(
            relation: PgQuery::RangeVar.new(
              relname: 'shoe',
              inh: true,
              relpersistence: 'p',
              location: 45
            ),
            rulename: 'shoe_ins_protect',
            event: :CMD_INSERT,
            instead: true
          )
        )
      )
    )
  end

  it 'parses CREATE TRIGGER' do
    query = described_class.parse('CREATE TRIGGER check_update
                           BEFORE UPDATE ON accounts
                           FOR EACH ROW
                           EXECUTE PROCEDURE check_account_update()')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['accounts']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_trig_stmt: PgQuery::CreateTrigStmt.new(
            trigname: 'check_update',
            relation: PgQuery::RangeVar.new(
              relname: 'accounts',
              inh: true,
              relpersistence: 'p',
              location: 72
            ),
            funcname: [
              PgQuery::Node.new(string: PgQuery::String.new(str: 'check_account_update'))
            ],
            row: true,
            timing: PgQuery::TRIGGER_TYPE_BEFORE,
            events: PgQuery::TRIGGER_TYPE_UPDATE
          )
        )
      )
    )
  end

  it 'parses DROP SCHEMA' do
    query = described_class.parse('DROP SCHEMA myschema')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(string: PgQuery::String.new(str: 'myschema'))
            ],
            remove_type: :OBJECT_SCHEMA,
            behavior: :DROP_RESTRICT
          )
        )
      )
    )
  end

  it 'parses DROP VIEW' do
    query = described_class.parse('DROP VIEW myview, myview2')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(
                list: PgQuery::List.new(
                  items: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'myview'))
                  ]
                )
              ),
              PgQuery::Node.new(
                list: PgQuery::List.new(
                  items: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'myview2'))
                  ]
                )
              )
            ],
            remove_type: :OBJECT_VIEW,
            behavior: :DROP_RESTRICT
          )
        )
      )
    )
  end

  it 'parses DROP INDEX' do
    query = described_class.parse('DROP INDEX CONCURRENTLY myindex')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(
                list: PgQuery::List.new(
                  items: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'myindex'))
                  ]
                )
              )
            ],
            remove_type: :OBJECT_INDEX,
            behavior: :DROP_RESTRICT,
            concurrent: true
          )
        )
      )
    )
  end

  it 'parses DROP RULE' do
    query = described_class.parse('DROP RULE myrule ON mytable CASCADE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(
                list: PgQuery::List.new(
                  items: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'mytable')),
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'myrule'))
                  ]
                )
              )
            ],
            remove_type: :OBJECT_RULE,
            behavior: :DROP_CASCADE
          )
        )
      )
    )
  end

  it 'parses DROP TRIGGER' do
    query = described_class.parse('DROP TRIGGER IF EXISTS mytrigger ON mytable RESTRICT')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(
                list: PgQuery::List.new(
                  items: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'mytable')),
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'mytrigger'))
                  ]
                )
              )
            ],
            remove_type: :OBJECT_TRIGGER,
            behavior: :DROP_RESTRICT,
            missing_ok: true
          )
        )
      )
    )
  end

  it 'parses GRANT' do
    query = described_class.parse('GRANT INSERT, UPDATE ON mytable TO myuser')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['mytable']
    expect(query.ddl_tables).to eq ['mytable']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          grant_stmt: PgQuery::GrantStmt.new(
            is_grant: true,
            targtype: :ACL_TARGET_OBJECT,
            objtype: :OBJECT_TABLE,
            objects: [
              PgQuery::Node.new(
                range_var: PgQuery::RangeVar.new(
                  relname: 'mytable',
                  inh: true,
                  relpersistence: 'p',
                  location: 24
                )
              )
            ],
            privileges: [
              PgQuery::Node.new(access_priv: PgQuery::AccessPriv.new(priv_name: 'insert')),
              PgQuery::Node.new(access_priv: PgQuery::AccessPriv.new(priv_name: 'update'))
            ],
            grantees: [
              PgQuery::Node.new(role_spec: PgQuery::RoleSpec.new(roletype: :ROLESPEC_CSTRING, rolename: 'myuser', location: 35))
            ],
            behavior: :DROP_RESTRICT
          )
        )
      )
    )
  end

  it 'parses REVOKE' do
    query = described_class.parse('REVOKE admins FROM joe')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          grant_role_stmt: PgQuery::GrantRoleStmt.new(
            granted_roles: [
              PgQuery::Node.new(access_priv: PgQuery::AccessPriv.new(priv_name: 'admins'))
            ],
            grantee_roles: [
              PgQuery::Node.new(role_spec: PgQuery::RoleSpec.new(roletype: :ROLESPEC_CSTRING, rolename: 'joe', location: 19))
            ],
            behavior: :DROP_RESTRICT
          )
        )
      )
    )
  end

  it 'parses TRUNCATE' do
    query = described_class.parse('TRUNCATE bigtable, "fattable" RESTART IDENTITY')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['bigtable', 'fattable']
    expect(query.ddl_tables).to eq ['bigtable', 'fattable']
    expect(query.tables_with_details).to eq [
      {
        inh: true,
        location: 9,
        name: "bigtable",
        relname: "bigtable",
        schemaname: nil,
        type: :ddl
      },
      {
        inh: true,
        location: 19,
        name: "fattable",
        relname: "fattable",
        schemaname: nil,
        type: :ddl
      }
    ]
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          truncate_stmt: PgQuery::TruncateStmt.new(
            relations: [
              PgQuery::Node.new(
                range_var: PgQuery::RangeVar.new(
                  relname: 'bigtable',
                  inh: true,
                  relpersistence: 'p',
                  location: 9
                )
              ),
              PgQuery::Node.new(
                range_var: PgQuery::RangeVar.new(
                  relname: 'fattable',
                  inh: true,
                  relpersistence: 'p',
                  location: 19
                )
              )
            ],
            restart_seqs: true,
            behavior: :DROP_RESTRICT
          )
        )
      )
    )
  end

  it 'parses WITH' do
    query = described_class.parse('WITH a AS (SELECT * FROM x WHERE x.y = ? AND x.z = 1) SELECT * FROM a')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['x']
    expect(query.cte_names).to eq ['a']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          select_stmt: PgQuery::SelectStmt.new(
            target_list: [
              PgQuery::Node.new(
                res_target: PgQuery::ResTarget.new(
                  val: PgQuery::Node.new(
                    column_ref: PgQuery::ColumnRef.new(
                      fields: [
                        PgQuery::Node.new(
                          a_star: PgQuery::A_Star.new
                        )
                      ],
                      location: 61
                    )
                  ),
                  location: 61
                )
              )
            ],
            from_clause: [
              PgQuery::Node.new(
                range_var: PgQuery::RangeVar.new(
                  relname: 'a',
                  inh: true,
                  relpersistence: 'p',
                  location: 68
                )
              )
            ],
            limit_option: :LIMIT_OPTION_DEFAULT,
            op: :SETOP_NONE,
            with_clause: PgQuery::WithClause.new(
              ctes: [
                PgQuery::Node.new(
                  common_table_expr: PgQuery::CommonTableExpr.new(
                    ctematerialized: :CTEMaterializeDefault,
                    ctename: 'a',
                    ctequery: PgQuery::Node.new(
                      select_stmt: PgQuery::SelectStmt.new(
                        target_list: [
                          PgQuery::Node.new(
                            res_target: PgQuery::ResTarget.new(
                              val: PgQuery::Node.new(
                                column_ref: PgQuery::ColumnRef.new(
                                  fields: [
                                    PgQuery::Node.new(
                                      a_star: PgQuery::A_Star.new
                                    )
                                  ],
                                  location: 18
                                )
                              ),
                              location: 18
                            )
                          )
                        ],
                        from_clause: [
                          PgQuery::Node.new(
                            range_var: PgQuery::RangeVar.new(
                              relname: 'x',
                              inh: true,
                              relpersistence: 'p',
                              location: 25
                            )
                          )
                        ],
                        limit_option: :LIMIT_OPTION_DEFAULT,
                        op: :SETOP_NONE,
                        where_clause: PgQuery::Node.new(
                          bool_expr: PgQuery::BoolExpr.new(
                            boolop: :AND_EXPR,
                            args: [
                              PgQuery::Node.new(
                                a_expr: PgQuery::A_Expr.new(
                                  kind: :AEXPR_OP,
                                  name: [
                                    PgQuery::Node.new(string: PgQuery::String.new(str: '='))
                                  ],
                                  lexpr: PgQuery::Node.new(
                                    column_ref: PgQuery::ColumnRef.new(
                                      fields: [
                                        PgQuery::Node.new(string: PgQuery::String.new(str: 'x')),
                                        PgQuery::Node.new(string: PgQuery::String.new(str: 'y'))
                                      ],
                                      location: 33
                                    )
                                  ),
                                  rexpr: PgQuery::Node.new(
                                    param_ref: PgQuery::ParamRef.new(
                                      location: 39
                                    )
                                  ),
                                  location: 37
                                )
                              ),
                              PgQuery::Node.new(
                                a_expr: PgQuery::A_Expr.new(
                                  kind: :AEXPR_OP,
                                  name: [
                                    PgQuery::Node.new(string: PgQuery::String.new(str: '='))
                                  ],
                                  lexpr: PgQuery::Node.new(
                                    column_ref: PgQuery::ColumnRef.new(
                                      fields: [
                                        PgQuery::Node.new(string: PgQuery::String.new(str: 'x')),
                                        PgQuery::Node.new(string: PgQuery::String.new(str: 'z'))
                                      ],
                                      location: 45
                                    )
                                  ),
                                  rexpr: PgQuery::Node.new(
                                    a_const: PgQuery::A_Const.new(
                                      val: PgQuery::Node.new(integer: PgQuery::Integer.new(ival: 1)),
                                      location: 51
                                    )
                                  ),
                                  location: 49
                                )
                              )
                            ],
                            location: 41
                          )
                        )
                      )
                    ),
                    location: 5
                  )
                )
              ]
            )
          )
        )
      )
    )
  end

  it 'parses multi-line function definitions' do
    query = described_class.parse('CREATE OR REPLACE FUNCTION thing(parameter_thing text)
  RETURNS bigint AS
$BODY$
DECLARE
        local_thing_id BIGINT := 0;
BEGIN
        SELECT thing_id INTO local_thing_id FROM thing_map
        WHERE
                thing_map_field = parameter_thing
        ORDER BY 1 LIMIT 1;

        IF NOT FOUND THEN
                local_thing_id = 0;
        END IF;
        RETURN local_thing_id;
END;
$BODY$
  LANGUAGE plpgsql STABLE')
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_function_stmt: PgQuery::CreateFunctionStmt.new(
            replace: true,
            funcname: [
              PgQuery::Node.new(string: PgQuery::String.new(str: 'thing'))
            ],
            parameters: [
              PgQuery::Node.new(function_parameter: PgQuery::FunctionParameter.new(
                name: 'parameter_thing',
                arg_type: PgQuery::TypeName.new(
                  names: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'text'))
                  ],
                  typemod: -1,
                  location: 49
                ),
                mode: :FUNC_PARAM_IN
              ))
            ],
            return_type: PgQuery::TypeName.new(
              names: [
                PgQuery::Node.new(string: PgQuery::String.new(str: 'pg_catalog')),
                PgQuery::Node.new(string: PgQuery::String.new(str: 'int8'))
              ],
              typemod: -1,
              location: 65
            ),
            options: [
              PgQuery::Node.new(
                def_elem: PgQuery::DefElem.new(
                  defname: 'as',
                  arg: PgQuery::Node.new(
                    list: PgQuery::List.new(
                      items: [
                        PgQuery::Node.new(
                          string: PgQuery::String.new(str: "\nDECLARE\n        local_thing_id BIGINT := 0;\nBEGIN\n        SELECT thing_id INTO local_thing_id FROM thing_map\n        WHERE\n                thing_map_field = parameter_thing\n        ORDER BY 1 LIMIT 1;\n\n        IF NOT FOUND THEN\n                local_thing_id = 0;\n        END IF;\n        RETURN local_thing_id;\nEND;\n")
                        )
                      ]
                    )
                  ),
                  defaction: :DEFELEM_UNSPEC,
                  location: 72
                )
              ),
              PgQuery::Node.new(
                def_elem: PgQuery::DefElem.new(
                  defname: 'language',
                  arg: PgQuery::Node.new(
                    string: PgQuery::String.new(str: 'plpgsql')
                  ),
                  defaction: :DEFELEM_UNSPEC,
                  location: 407
                )
              ),
              PgQuery::Node.new(
                def_elem: PgQuery::DefElem.new(
                  defname: 'volatility',
                  arg: PgQuery::Node.new(
                    string: PgQuery::String.new(str: 'stable')
                  ),
                  defaction: :DEFELEM_UNSPEC,
                  location: 424
                )
              )
            ]
          )
        )
      )
    )
  end

  it 'parses table functions' do
    query = described_class.parse("CREATE FUNCTION getfoo(int) RETURNS TABLE (f1 int) AS '
    SELECT * FROM foo WHERE fooid = $1;
' LANGUAGE SQL")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          create_function_stmt: PgQuery::CreateFunctionStmt.new(
            funcname: [
              PgQuery::Node.new(string: PgQuery::String.new(str: 'getfoo'))
            ],
            parameters: [
              PgQuery::Node.new(
                function_parameter: PgQuery::FunctionParameter.new(
                  arg_type: PgQuery::TypeName.new(
                    names: [
                      PgQuery::Node.new(string: PgQuery::String.new(str: 'pg_catalog')),
                      PgQuery::Node.new(string: PgQuery::String.new(str: 'int4'))
                    ],
                    typemod: -1,
                    location: 23
                  ),
                  mode: :FUNC_PARAM_IN
                )
              ),
              PgQuery::Node.new(
                function_parameter: PgQuery::FunctionParameter.new(
                  name: 'f1',
                  arg_type: PgQuery::TypeName.new(
                    names: [
                      PgQuery::Node.new(string: PgQuery::String.new(str: 'pg_catalog')),
                      PgQuery::Node.new(string: PgQuery::String.new(str: 'int4'))
                    ],
                    typemod: -1,
                    location: 46
                  ),
                  mode: :FUNC_PARAM_TABLE
                )
              )
            ],
            return_type: PgQuery::TypeName.new(
              names: [
                PgQuery::Node.new(string: PgQuery::String.new(str: 'pg_catalog')),
                PgQuery::Node.new(string: PgQuery::String.new(str: 'int4'))
              ],
              setof: true,
              typemod: -1,
              location: 36
            ),
            options: [
              PgQuery::Node.new(
                def_elem: PgQuery::DefElem.new(
                  defname: 'as',
                  arg: PgQuery::Node.new(
                    list: PgQuery::List.new(
                      items: [
                        PgQuery::Node.new(
                          string: PgQuery::String.new(str: "\n    SELECT * FROM foo WHERE fooid = $1;\n")
                        )
                      ]
                    )
                  ),
                  defaction: :DEFELEM_UNSPEC,
                  location: 51
                )
              ),
              PgQuery::Node.new(
                def_elem: PgQuery::DefElem.new(
                  defname: 'language',
                  arg: PgQuery::Node.new(
                    string: PgQuery::String.new(str: 'sql')
                  ),
                  defaction: :DEFELEM_UNSPEC,
                  location: 98
                )
              )
            ]
          )
        )
      )
    )
  end

  # https://github.com/lfittl/pg_query/issues/38
  it 'correctly finds nested tables in select clause' do
    query = described_class.parse("select u.email, (select count(*) from enrollments e where e.user_id = u.id) as num_enrollments from users u")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'enrollments']
    expect(query.select_tables).to eq ['users', 'enrollments']
  end

  # https://github.com/lfittl/pg_query/issues/52
  it 'correctly separates CTE names from table names' do
    query = described_class.parse("WITH cte_name AS (SELECT 1) SELECT * FROM table_name, cte_name")
    expect(query.cte_names).to eq ['cte_name']
    expect(query.tables).to eq ['table_name']
    expect(query.select_tables).to eq ['table_name']
  end

  it 'correctly finds nested tables in from clause' do
    query = described_class.parse("select u.* from (select * from users) u")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users']
    expect(query.select_tables).to eq ['users']
  end

  it 'correctly finds nested tables in where clause' do
    query = described_class.parse("select users.id from users where 1 = (select count(*) from user_roles)")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
    expect(query.select_tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds tables in a select that has sub-selects without from clause' do
    query = described_class.parse('SELECT * FROM pg_catalog.pg_class c JOIN (SELECT 17650 AS oid UNION ALL SELECT 17663 AS oid) vals ON c.oid = vals.oid')
    expect(query.warnings).to eq []
    expect(query.tables).to eq ["pg_catalog.pg_class"]
    expect(query.select_tables).to eq ["pg_catalog.pg_class"]
    expect(query.filter_columns).to eq [["pg_catalog.pg_class", "oid"], ["vals", "oid"]]
  end

  it 'traverse boolean expressions in where clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      where users.id IN (
        select user_roles.user_id
        from user_roles
      ) and (users.created_at between '2016-06-01' and '2016-06-30')
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the order by clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      order by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the order by clause with multiple entries' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      order by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      ) asc, (
        select max(user_logins.role_id)
        from user_logins
        where user_logins.user_id = users.id
      ) desc
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles', 'user_logins']
  end

  it 'correctly finds nested tables in the group by clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the group by clause with multiple entries' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by (
        select max(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      ), (
        select max(user_logins.role_id)
        from user_logins
        where user_logins.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles', 'user_logins']
  end

  it 'correctly finds nested tables in the having clause' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by users.id
      having 1 > (
        select count(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in the having clause with a boolean expression' do
    query = described_class.parse(<<-SQL)
      select users.*
      from users
      group by users.id
      having true and 1 > (
        select count(user_roles.role_id)
        from user_roles
        where user_roles.user_id = users.id
      )
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['users', 'user_roles']
  end

  it 'correctly finds nested tables in a subselect on a join' do
    query = described_class.parse(<<-SQL)
      select foo.*
      from foo
      join ( select * from bar ) b
      on b.baz = foo.quux
    SQL
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['foo', 'bar']
  end

  it 'does not list CTEs as tables after a union select' do
    query = described_class.parse(<<-SQL)
      with cte_a as (
        select * from table_a
      ), cte_b as (
        select * from table_b
      )

      select id from table_c
      left join cte_b on
        table_c.id = cte_b.c_id
      union
      select * from cte_a
    SQL
    expect(query.tables).to match_array(['table_a', 'table_b', 'table_c'])
    expect(query.cte_names).to match_array(['cte_a', 'cte_b'])
  end

  describe 'parsing INSERT' do
    it 'finds the table inserted into' do
      query = described_class.parse(<<-SQL)
        insert into users(pk, name) values (1, 'bob');
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to eq(['users'])
    end

    it 'finds tables in being selected from for insert' do
      query = described_class.parse(<<-SQL)
        insert into users(pk, name) select pk, name from other_users;
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end

    it 'finds tables in a CTE' do
      query = described_class.parse(<<-SQL)
        with cte as (
          select pk, name from other_users
        )
        insert into users(pk, name) select * from cte;
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end
  end

  describe 'parsing UPDATE' do
    it 'finds the table updateed into' do
      query = described_class.parse(<<-SQL)
        update users set name = 'bob';
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to eq(['users'])
    end

    it 'finds tables in a sub-select' do
      query = described_class.parse(<<-SQL)
        update users set name = (select name from other_users limit 1);
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end

    it 'finds tables in a CTE' do
      query = described_class.parse(<<-SQL)
        with cte as (
          select name from other_users limit 1
        )
        update users set name = (select name from cte);
      SQL
      expect(query.warnings).to be_empty
      expect(query.tables).to match_array(['users', 'other_users'])
    end
  end

  it 'handles DROP TYPE' do
    query = described_class.parse("DROP TYPE IF EXISTS repack.pk_something")
    expect(query.warnings).to eq []
    expect(query.tables).to eq []
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          drop_stmt: PgQuery::DropStmt.new(
            objects: [
              PgQuery::Node.new(
                type_name: PgQuery::TypeName.new(
                  names: [
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'repack')),
                    PgQuery::Node.new(string: PgQuery::String.new(str: 'pk_something'))
                  ],
                  typemod: -1,
                  location: 20
                )
              )
            ],
            remove_type: :OBJECT_TYPE,
            behavior: :DROP_RESTRICT,
            missing_ok: true
          )
        )
      )
    )
  end

  it 'handles COPY' do
    query = described_class.parse("COPY (SELECT test FROM abc) TO STDOUT WITH (FORMAT 'csv')")
    expect(query.warnings).to eq []
    expect(query.tables).to eq ['abc']
    expect(query.tree.stmts.first).to eq(
      PgQuery::RawStmt.new(
        stmt: PgQuery::Node.new(
          copy_stmt: PgQuery::CopyStmt.new(
            query: PgQuery::Node.new(
              select_stmt: PgQuery::SelectStmt.new(
                target_list: [
                  PgQuery::Node.new(
                    res_target: PgQuery::ResTarget.new(
                      val: PgQuery::Node.new(
                        column_ref: PgQuery::ColumnRef.new(
                          fields: [
                            PgQuery::Node.new(string: PgQuery::String.new(str: 'test'))
                          ],
                          location: 13
                        )
                      ),
                      location: 13
                    )
                  )
                ],
                from_clause: [
                  PgQuery::Node.new(range_var: PgQuery::RangeVar.new(
                    relname: 'abc',
                    inh: true,
                    relpersistence: 'p',
                    location: 23
                  ))
                ],
                limit_option: :LIMIT_OPTION_DEFAULT,
                op: :SETOP_NONE
              )
            ),
            options: [
              PgQuery::Node.new(def_elem: PgQuery::DefElem.new(
                defname: 'format',
                arg: PgQuery::Node.new(string: PgQuery::String.new(str: 'csv')),
                defaction: :DEFELEM_UNSPEC,
                location: 44
              ))
            ]
          )
        )
      )
    )
  end

  describe 'parsing CREATE TABLE AS' do
    it 'finds tables in the subquery' do
      query = described_class.parse(<<-SQL)
        CREATE TABLE foo AS
          SELECT * FROM bar;
      SQL
      expect(query.tables).to eq(['foo', 'bar'])
      expect(query.ddl_tables).to eq(['foo'])
      expect(query.select_tables).to eq(['bar'])
    end

    it 'finds tables in the subquery with UNION' do
      query = described_class.parse(<<-SQL)
        CREATE TABLE foo AS
          SELECT id FROM bar UNION SELECT id from baz;
      SQL

      expect(query.tables).to eq(['foo', 'bar', 'baz'])
      expect(query.ddl_tables).to eq(['foo'])
      expect(query.select_tables).to eq(['bar', 'baz'])
    end
  end
end

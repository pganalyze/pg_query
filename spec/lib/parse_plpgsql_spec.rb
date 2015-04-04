require 'spec_helper'

describe PgQuery, 'parsing PL/pgSQL' do
  it 'parses a simple function' do
    func_def = """
DECLARE
    r foo%rowtype;
BEGIN
    SELECT * FROM foo WHERE fooid > 0;
    RETURN;
END
"""
    func = PgQuery.parse_plpgsql(func_def)
    expect(func.warnings).to eq []
    expect(func.parsetree).to eq(
{"signature"=>"inline_code_block",
 "data_area"=>[{"entry"=>0, "type"=>"REC", "refname"=>"found"}, {"entry"=>1, "type"=>"REC", "refname"=>"r"}],
 "definition"=>
  {"lineno"=>4,
   "type"=>"block",
   "name"=>"*unnamed*",
   "statements"=>
    [{"lineno"=>5,
      "type"=>"EXECSQL",
      "query"=>"SELECT * FROM foo WHERE fooid > 0"},
     {"lineno"=>6, "type"=>"RETURN", "expr"=>nil}]}})
  end

  it 'returns syntax errors' do
    func_def = 'INVALID STUFF'
    expect { PgQuery.parse_plpgsql(func_def) }.to raise_error do |error|
      expect(error).to be_a PgQuery::ParseError
      expect(error.message).to eq 'syntax error at or near "INVALID"'
    end
  end

  it 'parses a function with a non-void return type' do
    pending
    func_def = """
BEGIN
    IF v_version IS NULL THEN
        RETURN v_name;
    END IF;
    RETURN v_name || '/' || v_version;
END;
"""
    func = PgQuery.parse_plpgsql(func_def)
  end

  it 'parses a complex function' do
    func_def = """
DECLARE
    referrer_key RECORD;  -- declare a generic record to be used in a FOR
    func_body text;
    func_cmd text;
BEGIN
    func_body := 'BEGIN';

    -- Notice how we scan through the results of a query in a FOR loop
    -- using the FOR <record> construct.

    FOR referrer_key IN SELECT * FROM cs_referrer_keys ORDER BY try_order LOOP
        func_body := func_body ||
          ' IF v_' || referrer_key.kind
          || ' LIKE ' || quote_literal(referrer_key.key_string)
          || ' THEN RETURN ' || quote_literal(referrer_key.referrer_type)
          || '; END IF;' ;
    END LOOP;

    func_body := func_body || ' RETURN NULL; END;';

    func_cmd :=
      'CREATE OR REPLACE FUNCTION cs_find_referrer_type(v_host varchar,
                                                        v_domain varchar,
                                                        v_url varchar)
        RETURNS varchar AS '
      || quote_literal(func_body)
      || ' LANGUAGE plpgsql;' ;

    EXECUTE func_cmd;
END;
"""
    func = PgQuery.parse_plpgsql(func_def)
    expect(func.warnings).to eq []
    expect(func.parsetree).to match(
{"signature"=>"inline_code_block",
 "data_area"=>
  [{"entry"=>0, "type"=>"REC", "refname"=>"found"},
   {"entry"=>1, "type"=>"REC", "refname"=>"referrer_key"},
   {"entry"=>2, "type"=>"REC", "refname"=>"func_body"},
   {"entry"=>3, "type"=>"REC", "refname"=>"func_cmd"},
   {"entry"=>4, "type"=>"RECFIELD", "fieldname"=>"kind", "recparentno"=>1},
   {"entry"=>5,
    "type"=>"RECFIELD",
    "fieldname"=>"key_string",
    "recparentno"=>1},
   {"entry"=>6,
    "type"=>"RECFIELD",
    "fieldname"=>"referrer_type",
    "recparentno"=>1}],
 "definition"=>
  {"lineno"=>6,
   "type"=>"block",
   "name"=>"*unnamed*",
   "statements"=>
    [{"lineno"=>7, "type"=>"ASSIGN", "varno"=>2, "expr"=>"SELECT 'BEGIN'"},
     {"lineno"=>12,
      "type"=>"FORS",
      "refname"=>"referrer_key",
      "expr"=>"SELECT * FROM cs_referrer_keys ORDER BY try_order",
      "statements"=>
       [{"lineno"=>13,
         "type"=>"ASSIGN",
         "varno"=>2,
         "expr"=>
          "SELECT func_body ||\n          ' IF v_' || referrer_key.kind\n          || ' LIKE ' || quote_literal(referrer_key.key_string)\n          || ' THEN RETURN ' || quote_literal(referrer_key.referrer_type)\n          || '; END IF;'"}]},
     {"lineno"=>20,
      "type"=>"ASSIGN",
      "varno"=>2,
      "expr"=>"SELECT func_body || ' RETURN NULL; END;'"},
     {"lineno"=>22,
      "type"=>"ASSIGN",
      "varno"=>3,
      "expr"=>
       "SELECT 'CREATE OR REPLACE FUNCTION cs_find_referrer_type(v_host varchar,\n                                                        v_domain varchar,\n                                                        v_url varchar)\n        RETURNS varchar AS '\n      || quote_literal(func_body)\n      || ' LANGUAGE plpgsql;'"},
     {"lineno"=>30,
      "type"=>"EXECUTE",
      "expr"=>"SELECT func_cmd",
      "strict"=>false},
     {"lineno"=>0, "type"=>"RETURN", "expr"=>nil}]}})
  end
end

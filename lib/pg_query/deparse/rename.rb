module PgQuery
  module Deparse
    module Rename
      # relation, subname and object is the array key in the node.
      # Array return five value. First is the type like a TRIGGER, TABLE, DOMAIN
      # Other values may be parameter or SQL key.
      #
      # If node['renameType'] is the integer 13 (OBJECT_TYPE_DOMCONSTRAINT),
      # then return value of this method will be:
      #
      #   %w[DOMAIN object RENAME CONSTRAINT subname]
      #
      # Which will be composed into the SQL as:
      #
      #   ALTER {type} {name} RENAME CONSTRAINT {subname} TO {newname}
      #
      def self.commands(node)
        action = RENAME_MAPPING[node['renameType']] || raise(format("Can't deparse: %s", node.inspect))
        PgQuery::Deparse.instance_exec(node, &action)
      end

      RENAME_MAPPING = {
        OBJECT_TYPE_CONVERSION       => ->(_node) { %w[CONVERSION object RENAME] },
        OBJECT_TYPE_TABLE            => ->(_node) { %w[TABLE relation RENAME] },
        OBJECT_TYPE_TABCONSTRAINT    => ->(_node) { %w[TABLE relation RENAME CONSTRAINT subname] },
        OBJECT_TYPE_INDEX            => ->(_node) { %w[INDEX relation RENAME] },
        OBJECT_TYPE_MATVIEW          => ->(_node) { ['MATERIALIZED VIEW', 'relation', 'RENAME'] },
        OBJECT_TYPE_TABLESPACE       => ->(_node) { %w[TABLESPACE subname RENAME] },
        OBJECT_TYPE_VIEW             => ->(_node) { %w[VIEW relation RENAME] },
        OBJECT_TYPE_COLUMN           => ->(_node) { %w[TABLE relation RENAME COLUMN subname] },
        OBJECT_TYPE_COLLATION        => ->(_node) { %w[COLLATION object RENAME] },
        OBJECT_TYPE_TYPE             => ->(_node) { %w[TYPE object RENAME] },
        OBJECT_TYPE_DOMCONSTRAINT    => ->(_node) { %w[DOMAIN object RENAME CONSTRAINT subname] },
        OBJECT_TYPE_RULE             => ->(_node) { %w[RULE subname ON relation RENAME] },
        OBJECT_TYPE_TRIGGER          => ->(_node) { %w[TRIGGER subname ON relation RENAME] },
        OBJECT_TYPE_AGGREGATE        => ->(_node) { %w[AGGREGATE object RENAME] },
        OBJECT_TYPE_FUNCTION         => ->(_node) { %w[FUNCTION object RENAME] }
      }.freeze
    end
  end
end

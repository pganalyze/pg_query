module PgQuery
  module Deparse
    module AlterTable
      # Returns a list of strings of length one or length two. The first string
      # will be placed before the column name and the second, if present, will be
      # placed after.
      #
      # If node['subtype'] is the integer 4 (AT_DropNotNull),
      # then return value of this method will be:
      #
      #   ['ALTER COLUMN', 'DROP NOT NULL']
      #
      # Which will be composed into the SQL as:
      #
      #   ALTER COLUMN {column_name} DROP NOT NULL
      #
      def self.commands(node)
        action = ALTER_TABLE_TYPES_MAPPING[node['subtype']] || raise(format("Can't deparse: %s", node.inspect))
        PgQuery::Deparse.instance_exec(node, &action)
      end

      ALTER_TABLE_TYPES_MAPPING = {
        AT_AddColumn                 => ->(_node) { ['ADD COLUMN'] },
        AT_ColumnDefault             => ->(node) { ['ALTER COLUMN', node['def'] ? 'SET DEFAULT' : 'DROP DEFAULT'] },
        AT_DropNotNull               => ->(_node) { ['ALTER COLUMN', 'DROP NOT NULL'] },
        AT_SetNotNull                => ->(_node) { ['ALTER COLUMN', 'SET NOT NULL'] },
        AT_SetStatistics             => ->(_node) { ['ALTER COLUMN', 'SET STATISTICS'] },
        AT_SetOptions                => ->(_node) { ['ALTER COLUMN', 'SET'] },
        AT_ResetOptions              => ->(_node) { ['ALTER COLUMN', 'RESET'] },
        AT_SetStorage                => ->(_node) { ['ALTER COLUMN', 'SET STORAGE'] },
        AT_DropColumn                => ->(_node) { ['DROP'] },
        AT_AddIndex                  => ->(_node) { ['ADD INDEX'] },
        AT_AddConstraint             => ->(_node) { ['ADD'] },
        AT_AlterConstraint           => ->(_node) { ['ALTER CONSTRAINT'] },
        AT_ValidateConstraint        => ->(_node) { ['VALIDATE CONSTRAINT'] },
        AT_DropConstraint            => ->(_node) { ['DROP CONSTRAINT'] },
        AT_AlterColumnType           => ->(_node) { ['ALTER COLUMN', 'TYPE'] },
        AT_AlterColumnGenericOptions => ->(_node) { ['ALTER COLUMN', 'OPTIONS'] }
      }.freeze
    end
  end
end

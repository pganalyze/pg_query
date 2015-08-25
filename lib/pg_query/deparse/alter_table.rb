class PgQuery
  module Deparse
    module AlterTable
      # Returns a list of strings of length one or length two. The first string
      # will be placed before the column name and the second, if present, will be
      # placed after.
      #
      # If node['subtype'] is the integer 4,
      # Then the fifth ALTER_TABLE entry ('DropNotNull') will be selected
      # And the return value of this method will be:
      #
      #   ['ALTER COLUMN', 'DROP NOT NULL']
      #
      # Which will be composed into the SQL as:
      #
      #   ALTER COLUMN {column_name} DROP NOT NULL
      #
      def self.commands(node)
        action = ALTER_TABLE[ALTER_TABLE_COMMANDS[node['subtype']]]
        PgQuery::Deparse.instance_exec(node, &action)
      end

      # From include/nodes/parsenodes.h:1455
      #
      # Many of these will not be implemented here as they'll never be part of
      # valid SQL. We keep them all here in their original order because we look
      # these values up by array index.
      NOT_IMPLEMENTED = 'NotImplemented'
      ALTER_TABLE = {
        # add column
        'AddColumn'                  => -> (_node) { ['ADD COLUMN'] },
        # internal to commands/tablecmds.c
        'AddColumnRecurse'           => -> (_node) { NotImplemented },
        # implicitly via CREATE OR REPLACE VIEW
        'AddColumnToView'            => -> (_node) { NotImplemented },
        # alter column default
        'ColumnDefault'              => -> (node) { ['ALTER COLUMN', node['def'] ? 'SET DEFAULT' : 'DROP DEFAULT'] },
        # alter column drop not null
        'DropNotNull'                => -> (_node) { ['ALTER COLUMN', 'DROP NOT NULL'] },
        # alter column set not null
        'SetNotNull'                 => -> (_node) { ['ALTER COLUMN', 'SET NOT NULL'] },
        # alter column set statistics
        'SetStatistics'              => -> (_node) { ['ALTER COLUMN', 'SET STATISTICS'] },
        # alter column set ( options )
        'SetOptions'                 => -> (_node) { ['ALTER COLUMN', 'SET'] },
        # alter column reset ( options )
        'ResetOptions'               => -> (_node) { ['ALTER COLUMN', 'RESET'] },
        # alter column set storage
        'SetStorage'                 => -> (_node) { ['ALTER COLUMN', 'SET STORAGE'] },
        # drop column
        'DropColumn'                 => -> (_node) { ['DROP'] },
        # internal to commands/tablecmds.c
        'DropColumnRecurse'          => -> (_node) { NotImplemented },
        # add index
        'AddIndex'                   => -> (_node) { ['ADD INDEX'] },
        # internal to commands/tablecmds.c
        'ReAddIndex'                 => -> (_node) { NotImplemented },
        # add constraint
        'AddConstraint'              => -> (_node) { ['ADD'] },
        # internal to commands/tablecmds.c
        'AddConstraintRecurse'       => -> (_node) { NotImplemented },
        # internal to commands/tablecmds.c
        'ReAddConstraint'            => -> (_node) { NotImplemented },
        # alter constraint
        'AlterConstraint'            => -> (_node) { ['ALTER CONSTRAINT'] },
        # validate constraint
        'ValidateConstraint'         => -> (_node) { ['VALIDATE CONSTRAINT'] },
        # internal to commands/tablecmds.c
        'ValidateConstraintRecurse'  => -> (_node) { NotImplemented },
        # pre-processed add constraint (local in parser/parse_utilcmd.c)
        'ProcessedConstraint'        => -> (_node) { NotImplemented },
        # add constraint using existing index
        'AddIndexConstraint'         => -> (_node) { NotImplemented },
        # drop constraint
        'DropConstraint'             => -> (_node) { ['DROP CONSTRAINT'] },
        # internal to commands/tablecmds.c
        'DropConstraintRecurse'      => -> (_node) { NotImplemented },
        # alter column type
        'AlterColumnType'            => -> (_node) { ['ALTER COLUMN', 'TYPE'] },
        # alter column OPTIONS (...)
        'AlterColumnGenericOptions'  => -> (_node) { ['ALTER COLUMN', 'OPTIONS'] },
        # change owner
        'ChangeOwner'                => -> (_node) { NotImplemented },
        # CLUSTER ON
        'ClusterOn'                  => -> (_node) { NotImplemented },
        # SET WITHOUT CLUSTER
        'DropCluster'                => -> (_node) { NotImplemented },
        # SET WITH OIDS
        'AddOids'                    => -> (_node) { NotImplemented },
        # internal to commands/tablecmds.c
        'AddOidsRecurse'             => -> (_node) { NotImplemented },
        # SET WITHOUT OIDS
        'DropOids'                   => -> (_node) { NotImplemented },
        # SET TABLESPACE
        'SetTableSpace'              => -> (_node) { NotImplemented },
        # SET (...) -- AM specific parameters
        'SetRelOptions'              => -> (_node) { NotImplemented },
        # RESET (...) -- AM specific parameters
        'ResetRelOptions'            => -> (_node) { NotImplemented },
        # replace reloption list in its entirety
        'ReplaceRelOptions'          => -> (_node) { NotImplemented },
        # ENABLE TRIGGER name
        'EnableTrig'                 => -> (_node) { NotImplemented },
        # ENABLE ALWAYS TRIGGER name
        'EnableAlwaysTrig'           => -> (_node) { NotImplemented },
        # ENABLE REPLICA TRIGGER name
        'EnableReplicaTrig'          => -> (_node) { NotImplemented },
        # DISABLE TRIGGER name
        'DisableTrig'                => -> (_node) { NotImplemented },
        # ENABLE TRIGGER ALL
        'EnableTrigAll'              => -> (_node) { NotImplemented },
        # DISABLE TRIGGER ALL
        'DisableTrigAll'             => -> (_node) { NotImplemented },
        # ENABLE TRIGGER USER
        'EnableTrigUser'             => -> (_node) { NotImplemented },
        # DISABLE TRIGGER USER
        'DisableTrigUser'            => -> (_node) { NotImplemented },
        # ENABLE RULE name
        'EnableRule'                 => -> (_node) { NotImplemented },
        # ENABLE ALWAYS RULE name
        'EnableAlwaysRule'           => -> (_node) { NotImplemented },
        # ENABLE REPLICA RULE name
        'EnableReplicaRule'          => -> (_node) { NotImplemented },
        # DISABLE RULE name
        'DisableRule'                => -> (_node) { NotImplemented },
        # INHERIT parent
        'AddInherit'                 => -> (_node) { NotImplemented },
        # NO INHERIT parent
        'DropInherit'                => -> (_node) { NotImplemented },
        # OF <type_name>
        'AddOf'                      => -> (_node) { NotImplemented },
        # NOT OF
        'DropOf'                     => -> (_node) { NotImplemented },
        # REPLICA IDENTITY
        'ReplicaIdentity'            => -> (_node) { NotImplemented },
        # OPTIONS (...)
        'GenericOptions'             => -> (_node) { NotImplemented }
      }
      # Relying on Ruby's hashes maintaining key sort order
      ALTER_TABLE_COMMANDS = ALTER_TABLE.keys
    end
  end
end

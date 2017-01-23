module Dyna
  class Exporter
    include Filterable

    class << self
      def export(ddb, options = {})
        self.new(ddb, options).export
      end
    end

    def initialize(ddb, options = {})
      @ddb = ddb
      @options = options
    end

    def export
      @ddb.list_tables.table_names
        .reject { |name| should_skip(name) }
        .sort
        .each_with_object({}) do |table_name, result|
        result[table_name] = self.class.export_table(@ddb, table_name)
      end
    end

    def self.table_definition(describe_table)
      {
        'table_name'               => describe_table.table_name,
        'key_schema'               => key_schema(describe_table),
        'attribute_definitions'    => attribute_definitions(describe_table),
        'provisioned_throughput'   => {
          'read_capacity_units'    => describe_table.provisioned_throughput.read_capacity_units,
          'write_capacity_units'   => describe_table.provisioned_throughput.write_capacity_units,
        },
        'local_secondary_indexes'  => local_secondary_indexes(describe_table),
        'global_secondary_indexes' => global_secondary_indexes(describe_table),
      }
    end

    private
    def self.export_table(ddb, table_name)
      describe_table = ddb.describe_table(table_name: table_name).table
      table_definition(describe_table)
    end

    def self.key_schema(table)
      table.key_schema.map do |schema|
        {
          'attribute_name' => schema.attribute_name,
          'key_type'       => schema.key_type,
        }
      end
    end

    def self.attribute_definitions(table)
      table.attribute_definitions.map do |definition|
        {
          'attribute_name' => definition.attribute_name,
          'attribute_type' => definition.attribute_type,
        }
      end
    end

    def self.global_secondary_indexes(table)
      return nil unless table.global_secondary_indexes
      table.global_secondary_indexes.map do |index|
        {
          'index_name'             => index.index_name,
          'key_schema'             => key_schema(index),
          'projection'             => {
            'projection_type'      => index.projection.projection_type,
            'non_key_attributes'   => index.projection.non_key_attributes,
          },
          'provisioned_throughput' => {
            'read_capacity_units'  => index.provisioned_throughput.read_capacity_units,
            'write_capacity_units' => index.provisioned_throughput.write_capacity_units,
          },
        }
      end
    end

    def self.local_secondary_indexes(table)
      return nil unless table.local_secondary_indexes
      table.local_secondary_indexes.map do |index|
        {
          'index_name'           => index.index_name,
          'key_schema'           => key_schema(index),
          'projection'           => {
            'projection_type'    => index.projection.projection_type,
            'non_key_attributes' => index.projection.non_key_attributes,
          },
        }
      end
    end
  end
end

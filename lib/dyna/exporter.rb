module Dyna
  class Exporter
    include Logger::ClientHelper
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
        table_name:               describe_table.table_name,
        key_schema:               key_schema(describe_table),
        attribute_definitions:    attribute_definitions(describe_table),
        billing_mode:             describe_table.billing_mode_summary&.billing_mode,
        provisioned_throughput:   {
          read_capacity_units:    describe_table.provisioned_throughput.read_capacity_units,
          write_capacity_units:   describe_table.provisioned_throughput.write_capacity_units,
        },
        local_secondary_indexes:  local_secondary_indexes(describe_table),
        global_secondary_indexes: global_secondary_indexes(describe_table),
        stream_specification:     stream_specification(describe_table),
        scalable_targets:         scalable_targets(describe_table),
        scaling_policies:         scaling_policies(describe_table),
      }
    end

    def self.aas(aas)
      @aas = aas
    end

    private
    def self.export_table(ddb, table_name)
      describe_table = ddb.describe_table(table_name: table_name).table
      table_definition(describe_table)
    end

    def self.key_schema(table)
      table.key_schema.map do |schema|
        {
          attribute_name: schema.attribute_name,
          key_type:       schema.key_type,
        }
      end
    end

    def self.attribute_definitions(table)
      table.attribute_definitions.map do |definition|
        {
          attribute_name: definition.attribute_name,
          attribute_type: definition.attribute_type,
        }
      end
    end

    def self.global_secondary_indexes(table)
      return nil unless table.global_secondary_indexes
      table.global_secondary_indexes.map do |index|
        {
          index_name:             index.index_name,
          key_schema:             key_schema(index),
          projection:             {
            projection_type:      index.projection.projection_type,
            non_key_attributes:   index.projection.non_key_attributes,
          },
          provisioned_throughput: {
            read_capacity_units:  index.provisioned_throughput.read_capacity_units,
            write_capacity_units: index.provisioned_throughput.write_capacity_units,
          },
        }
      end
    end

    def self.local_secondary_indexes(table)
      return nil unless table.local_secondary_indexes
      table.local_secondary_indexes.map do |index|
        {
          index_name:           index.index_name,
          key_schema:           key_schema(index),
          projection:           {
            projection_type:    index.projection.projection_type,
            non_key_attributes: index.projection.non_key_attributes,
          },
        }
      end
    end

    def self.stream_specification(table)
      stream_spec = table.stream_specification
      return nil unless stream_spec
      {
        stream_enabled: stream_spec.stream_enabled,
        stream_view_type: stream_spec.stream_view_type,
      }
    end

    def self.scalable_targets(table)
      scalable_targets_by_resource_id["table/#{table.table_name}"]
    end

    def self.scalable_targets_by_resource_id
      return @scalable_targets_by_resource_id if @scalable_targets_by_resource_id

      results = []
      next_token = nil
      begin
        resp = @aas.describe_scalable_targets(service_namespace: 'dynamodb', next_token: next_token)
        resp.scalable_targets.each do |target|
          results.push(target)
        end
        next_token = resp.next_token
      end while next_token
      @scalable_targets_by_resource_id = results.group_by(&:resource_id)
    end

    def self.scaling_policies(table)
      scaling_policies_by_resource_id["table/#{table.table_name}"]
    end

    def self.scaling_policies_by_resource_id
      return @scaling_policies_by_resource_id if @scaling_policies_by_resource_id

      results = []
      next_token = nil
      begin
        resp = @aas.describe_scaling_policies(service_namespace: 'dynamodb', next_token: next_token)
        resp.scaling_policies.each do |policy|
          results.push(policy)
        end
        next_token = resp.next_token
      end while next_token
      @scaling_policies_by_resource_id = results.group_by(&:resource_id)
    end
  end
end

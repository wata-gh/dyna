module Dyna
  class DynamoDBWrapper
    include Logger::ClientHelper

    def initialize(ddb, options)
      @ddb = ddb
      @options = options.dup
    end

    def tables
      @ddb.list_tables.map { |tables|
        tables.table_names.map do |table_name|
          describe_table = @ddb.describe_table(table_name: table_name).table
          Table.new(@ddb, describe_table, @options)
        end
      }.flatten
    end

    def create(dsl)
      log(:info, 'Create Table', :cyan, "#{dsl.table_name}")

      unless @options.dry_run
        params = dsl.symbolize_keys
        params.delete(:scalable_targets)
        params.delete(:scaling_policies)
        result = @ddb.create_table(params)
        @options.updated = true
        result
      end
    end

    def updated?
      !!@options.updated
    end
  end
end

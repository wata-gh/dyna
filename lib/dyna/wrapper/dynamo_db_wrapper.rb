module Dyna
  class DynamoDBWrapper
    include Logger::ClientHelper

    def initialize(ddb, options)
      @ddb = ddb
      @options = options.dup
    end

    def tables
      @ddb.list_tables.table_names.map do |table_name|
        describe_table = @ddb.describe_table(table_name: table_name).table
        Table.new(@ddb, describe_table, @options)
      end
    end

    def create(dsl)
      log(:info, 'Create Table', :cyan, "#{dsl.table_name}")

      unless @options.dry_run
        result = @ddb.create_table(dsl.symbolize_keys)
        @options.updated = true
        result
      end
    end

    def updated?
      !!@options.updated
    end
  end
end

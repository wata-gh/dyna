module Dyna
  class Client
    include Logger::ClientHelper
    include Filterable

    def initialize(options = {})
      @options = OpenStruct.new(options)
      @options_hash = options
      @options.ddb = Aws::DynamoDB::Client.new
    end

    def apply(file)
      walk(file)
    end

    def export(options = {})
      exported = Exporter.export(@options.ddb, @options)

      converter = proc do |src|
        DSL.convert(@options.ddb.config.region, src)
      end

      if block_given?
        yield(exported, converter)
      else
        converter.call(exported)
      end
    end

    private
    def load_file(file)
      if file.kind_of?(String)
        open(file) do |f|
          parse(f.read, file)
        end
      elsif file.respond_to?(:read)
        parse(file.read, file.path)
      else
        raise TypeError, "can't load #{file}"
      end
    end

    def parse(src, path)
      DSL.define(src, path).result
    end

    def walk(file)
      dsl = load_file(file)
      dsl_ddbs = dsl.ddbs
      ddb_wrapper = DynamoDBWrapper.new(@options.ddb, @options)

      dsl_ddbs.each do |region, ddb_dsl|
        walk_ddb(ddb_dsl, ddb_wrapper) if @options.ddb.config.region == region
      end

      ddb_wrapper.updated?
    end

    def walk_ddb(ddb_dsl, ddb_wrapper)
      table_list_dsl = ddb_dsl.tables.group_by(&:table_name).each_with_object({}) do |(k, v), h|
        h[k] = v.first unless should_skip(k)
      end
      table_list_aws = ddb_wrapper.tables.group_by(&:table_name).each_with_object({}) do |(k, v), h|
        h[k] = v.first unless should_skip(k)
      end

      table_list_dsl.each do |name, table_dsl|
        unless table_list_aws[name]
          result = ddb_wrapper.create(table_dsl)
          if result
            table_list_aws[name] = DynamoDBWrapper::Table.new(
              @options.ddb,
              result.table_description,
              @options,
            )
          end
        end
      end

      table_list_dsl.each do |name, table_dsl|
        table_aws = table_list_aws.delete(name)
        next unless table_aws # only dry-run and should be created
        table_aws.update(table_dsl) unless table_aws.eql?(table_dsl)
      end

      table_list_aws.values.each(&:delete)
    end
  end
end

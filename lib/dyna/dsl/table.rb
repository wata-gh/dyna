module Dyna
  class DSL
    class DynamoDB
      class Table
        include Dyna::TemplateHelper

        def initialize(context, table_name, &block)
          @table_name = table_name
          @context = context

          @result = OpenStruct.new({
            :table_name => table_name,
            :dsl => yield,
          })
          @result.definition = definition
        end

        def result
          @result
        end

        def definition
          @result.dsl.merge(:table_name => @table_name).symbolize_keys
        end
      end
    end
  end
end

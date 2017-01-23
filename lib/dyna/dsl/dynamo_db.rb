module Dyna
  class DSL
    class DynamoDB
      include Dyna::TemplateHelper

      attr_reader :result

      def initialize(context, tables, &block)
        @context = context
        @result = OpenStruct.new({
          :tables => tables,
        })

        instance_eval(&block)
      end

      private
      def table(name, &block)
        if table_names.include?(name)
          raise "Table `#{name}` is already defined"
        end

        @result.tables << Table.new(@context, name, &block).result
      end

      def table_names
        @result.tables.map(&:table_name)
      end
    end
  end
end

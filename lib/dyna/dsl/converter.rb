module Dyna
  class DSL
    class Converter
      class << self
        def convert(region, exported)
          self.new(region, exported).convert
        end
      end

      def initialize(region, exported)
        @region = region
        @exported = exported
      end

      def convert
        output_dynamo_db
      end

      private
      def output_dynamo_db
        tables = @exported.map {|name, table|
          output_table(name, table)
        }.join("\n").strip

        <<-EOS
dynamo_db "#{@region}" do
  #{tables}
end
        EOS
      end

      def output_table(name, table)
        local_secondary_indexes = ''
        global_secondary_indexes = ''
        if table['local_secondary_indexes']
          local_secondary_indexes = <<-EOS.chomp

     "local_secondary_indexes" =>
       [{#{table['local_secondary_indexes'].map {|index| index.map {|k, v| k.inspect + ' => ' + v.inspect}}.join(",\n        ")}}],
          EOS
        end

        if table['global_secondary_indexes']
          global_secondary_indexes = <<-EOS.chomp

     "global_secondary_indexes" =>
       [{#{table['global_secondary_indexes'].map {|index| index.map {|k, v| k.inspect + ' => ' + v.inspect}}.join(",\n        ")}}],
          EOS
        end

        <<-EOS
  table "#{name}" do
    {"key_schema" =>
       [{#{table['key_schema'].map {|schema| schema.map {|k, v| k.inspect + ' => ' + v.inspect}.join(",\n        ")}.join("},\n        {")}}],
     "attribute_definitions" =>
       [#{table['attribute_definitions'].map {|h| h.inspect}.join(",\n        ")}],
     "provisioned_throughput" =>
       #{table['provisioned_throughput'].inspect},#{local_secondary_indexes}#{global_secondary_indexes}}
  end
        EOS
      end
    end
  end
end

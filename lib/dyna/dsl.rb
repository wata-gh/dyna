module Dyna
  class DSL
    include Dyna::TemplateHelper

    class << self
      def define(source, path)
        self.new(path) do
          eval(source, binding, path)
        end
      end

      def convert(region, exported)
        Converter.convert(region, exported)
      end
    end

    attr_reader :result

    def initialize(path, &block)
      @path = path
      @result = OpenStruct.new(:ddbs => {})

      @context = Hashie::Mash.new(
        :path      => path,
        :templates => {},
      )

      instance_eval(&block)
    end

    private
    def template(name, &block)
      @context.templates[name.to_s] = block
    end

    def require(file)
      tablefile = (file =~ %r|\A/|) ? file : File.expand_path(File.join(File.dirname(@path), file))

      if File.exist?(tablefile)
        instance_eval(File.read(tablefile), tablefile)
      elsif File.exist?(tablefile + '.rb')
        instance_eval(File.read(tablefile + '.rb'), tablefile + '.rb')
      else
        Kernel.require(file)
      end
    end

    def dynamo_db(region, &block)
      ddb = @result.ddbs[region]
      tables = ddb ? ddb.tables : []
      @result.ddbs[region] = DynamoDB.new(@context, tables, &block).result
    end
  end
end

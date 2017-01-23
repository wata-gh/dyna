class Hash
  def symbolize_keys
    self.each_with_object({}) do |(k, v), h|
      h[k.to_s.to_sym] = (v.is_a?(Hash) ? v.symbolize_keys : v)
      if v.is_a?(Array)
        h[k.to_s.to_sym] = v.each_with_object([]) do |h2, a|
          a << (h2.is_a?(Hash) ? h2.symbolize_keys : h2)
        end
      end
    end
  end
end

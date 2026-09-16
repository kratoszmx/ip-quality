# frozen_string_literal: true

# Child-process proxy overrides shared by direct and isolated routes.

module IpQuality
  module NetworkEnvironment
    PROXY_VARIABLE = /\A(?:all|http|https|no)_proxy\z/i

    module_function

    def without_proxy_variables(environment = ENV)
      environment.each_key.each_with_object({}) do |key, result|
        result[key] = nil if key.match?(PROXY_VARIABLE)
      end
    end
  end
end

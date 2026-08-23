# frozen_string_literal: true

require "yaml"
require_relative "safe_snapshot"

module IpQuality
  class ClashLeafProfile
    class Error < StandardError; end

    BUILTIN_PROXIES = %w[DIRECT REJECT REJECT-DROP PASS COMPATIBLE].freeze
    MAX_COLLECTION_NODES = 50_000
    MAX_NESTING_DEPTH = 64
    GROUP_BASENAME = "__IP_QUALITY_SELECTED_LEAF__".freeze

    Source = Struct.new(:description, :path, :document)

    def self.from_file(path)
      snapshot = SafeSnapshot.read(path)
      from_snapshot("explicit profile", snapshot)
    rescue SafeSnapshot::Error => error
      raise Error, error.message
    end

    def self.from_snapshot(description, snapshot)
      Source.new(description, snapshot.path, parse_yaml(snapshot.bytes, snapshot.path))
    end

    def self.parse_yaml(bytes, label)
      document = YAML.safe_load(
        bytes,
        permitted_classes: [],
        permitted_symbols: [],
        aliases: true,
        filename: label
      )
      raise Error, "profile root must be a YAML mapping" unless document.is_a?(Hash)

      validate_tree!(document)
      document
    rescue Psych::Exception => error
      raise Error, "profile YAML is not safely parseable: #{error.class}"
    end
    private_class_method :parse_yaml

    def self.validate_tree!(root)
      count = 0
      active = {}
      visit = lambda do |value, depth|
        raise Error, "profile nesting is too deep" if depth > MAX_NESTING_DEPTH

        count += 1
        raise Error, "profile contains too many values" if count > MAX_COLLECTION_NODES

        case value
        when Hash
          object_id = value.object_id
          raise Error, "recursive YAML aliases are not supported" if active[object_id]

          active[object_id] = true
          value.each do |key, child|
            raise Error, "profile mapping keys must be strings" unless key.is_a?(String)

            visit.call(child, depth + 1)
          end
          active.delete(object_id)
        when Array
          object_id = value.object_id
          raise Error, "recursive YAML aliases are not supported" if active[object_id]

          active[object_id] = true
          value.each { |child| visit.call(child, depth + 1) }
          active.delete(object_id)
        when String, Integer, Float, TrueClass, FalseClass, NilClass
          nil
        else
          raise Error, "unsupported YAML value type: #{value.class}"
        end
      end
      visit.call(root, 0)
    end
    private_class_method :validate_tree!

    def self.safe_text?(value, max_bytes = 512)
      value.is_a?(String) && !value.empty? && value.bytesize <= max_bytes && !value.match?(/[[:cntrl:]]/)
    end
    private_class_method :safe_text?

    attr_reader :source

    def initialize(source)
      @source = source
      @proxies = normalize_named_entries(source.document["proxies"], "proxies")
      @groups = normalize_named_entries(source.document["proxy-groups"], "proxy-groups", required: false)
      @proxy_by_name = unique_index(@proxies, "leaf proxy")
      @group_by_name = unique_index(@groups, "proxy group")
      builtin_collision = @proxy_by_name.keys.find { |name| BUILTIN_PROXIES.include?(name) }
      if builtin_collision
        raise Error, "leaf proxy name collides with Mihomo builtin: #{builtin_collision.inspect}"
      end
    end

    def leaf_names
      @proxies.map { |proxy| proxy.fetch("name") }
    end

    def render(leaf_name, mixed_port:)
      raise Error, "mixed port must be an unprivileged TCP port" unless mixed_port.is_a?(Integer) && mixed_port.between?(1024, 65_535)

      selected = @proxy_by_name[leaf_name]
      raise Error, "no exact leaf named #{leaf_name.inspect}" unless selected

      included = dependency_closure(selected)
      group_name = unique_group_name
      document = {
        "mixed-port" => mixed_port,
        "allow-lan" => false,
        "bind-address" => "127.0.0.1",
        "mode" => "rule",
        "log-level" => "warning",
        "ipv6" => true,
        "find-process-mode" => "off",
        "profile" => {
          "store-selected" => false,
          "store-fake-ip" => false
        },
        "proxies" => included,
        "proxy-groups" => [
          {
            "name" => group_name,
            "type" => "select",
            "proxies" => [leaf_name]
          }
        ],
        "rules" => ["MATCH,#{group_name}"]
      }
      fingerprint = source.document["global-client-fingerprint"]
      document["global-client-fingerprint"] = fingerprint if fingerprint.is_a?(String)
      YAML.dump(document)
    end

    private

    def normalize_named_entries(value, label, required: true)
      if value.nil? && !required
        return []
      end
      raise Error, "profile #{label} must be an array" unless value.is_a?(Array)
      raise Error, "profile #{label} is unexpectedly large" if value.length > 5_000

      value.map do |entry|
        raise Error, "every #{label} entry must be a mapping" unless entry.is_a?(Hash)

        name = entry["name"]
        unless self.class.send(:safe_text?, name)
          raise Error, "every #{label} entry must have a bounded, printable name"
        end
        entry
      end
    end

    def unique_index(entries, label)
      index = {}
      entries.each do |entry|
        name = entry.fetch("name")
        raise Error, "duplicate #{label} name: #{name.inspect}" if index.key?(name)

        index[name] = entry
      end
      index
    end

    def dependency_closure(selected)
      result = []
      visiting = {}
      visited = {}
      visit = lambda do |proxy|
        name = proxy.fetch("name")
        raise Error, "dialer-proxy dependency cycle at #{name.inspect}" if visiting[name]
        return if visited[name]

        visiting[name] = true
        dialer_dependencies(proxy).each do |dependency_name|
          next if BUILTIN_PROXIES.include?(dependency_name)
          if @group_by_name.key?(dependency_name)
            raise Error, "leaf #{name.inspect} depends on proxy group #{dependency_name.inspect}; choose a concrete leaf instead"
          end

          dependency = @proxy_by_name[dependency_name]
          raise Error, "leaf #{name.inspect} has missing dialer-proxy #{dependency_name.inspect}" unless dependency

          visit.call(dependency)
        end
        visiting.delete(name)
        visited[name] = true
        result << proxy
      end
      visit.call(selected)
      result
    end

    def dialer_dependencies(value, found = [])
      case value
      when Hash
        value.each do |key, child|
          if key == "dialer-proxy"
            unless child.is_a?(String) && !child.empty?
              raise Error, "dialer-proxy must name one concrete proxy"
            end
            found << child
          else
            dialer_dependencies(child, found)
          end
        end
      when Array
        value.each { |child| dialer_dependencies(child, found) }
      end
      found.uniq
    end

    def unique_group_name
      occupied = @proxy_by_name.merge(@group_by_name)
      candidate = GROUP_BASENAME.dup
      candidate << "_" while occupied.key?(candidate)
      candidate
    end
  end
end

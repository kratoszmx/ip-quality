# frozen_string_literal: true

require "yaml"
require_relative "../lib/safe_snapshot"
require_relative "profile"

module IpQuality
  class SubscriptionCatalog
    class Error < StandardError; end

    DEFAULT_APP_ROOT = File.expand_path(
      "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
    ).freeze
    MAX_REGISTRY_ITEMS = 1_000
    Entry = Struct.new(:name, :uid, :filename, keyword_init: true)

    attr_reader :entries

    def initialize(app_root: DEFAULT_APP_ROOT)
      @app_root = File.expand_path(app_root)
      @profiles_root = File.join(@app_root, "profiles")
      @registry_path = File.join(@app_root, "profiles.yaml")
      verify_boundaries!
      @registry_snapshot = SafeSnapshot.read(@registry_path)
      @entries = remote_entries(parse_registry(@registry_snapshot)).freeze
      raise Error, "Clash Verge has no cached remote subscriptions" if @entries.empty?
    rescue SafeSnapshot::Error => error
      raise Error, error.message
    end

    def find_exact(name)
      matches = @entries.select { |entry| entry.name == name }
      raise Error, "no cached remote subscription has that exact name" if matches.empty?
      raise Error, "the remote subscription name is ambiguous; select it by number" unless matches.one?

      matches.first
    end

    def source_for(entry)
      unless @entries.any? { |candidate| candidate.equal?(entry) }
        raise Error, "subscription selection does not belong to this verified catalog"
      end

      profile = SafeSnapshot.read(confined_profile_path(entry.filename))
      registry_after = SafeSnapshot.read(@registry_path)
      unless SafeSnapshot.same?(@registry_snapshot, registry_after)
        raise Error, "the Clash subscription registry changed while it was being selected; run again"
      end
      verify_boundaries!

      ClashLeafProfile.from_snapshot(
        "cached remote subscription #{entry.name.inspect} (read-only snapshot)",
        profile
      )
    rescue SafeSnapshot::Error => error
      raise Error, error.message
    end

    private

    def verify_boundaries!
      SafeSnapshot.verify_directory(@app_root)
      SafeSnapshot.verify_directory(@profiles_root)
    end

    def parse_registry(snapshot)
      document = YAML.safe_load(
        snapshot.bytes,
        permitted_classes: [],
        permitted_symbols: [],
        aliases: false,
        filename: snapshot.path
      )
      raise Error, "Clash subscription registry must be a YAML mapping" unless document.is_a?(Hash)

      items = document["items"]
      raise Error, "Clash subscription registry has no item list" unless items.is_a?(Array)
      raise Error, "Clash subscription registry is unexpectedly large" if items.length > MAX_REGISTRY_ITEMS

      items
    rescue Psych::Exception => error
      raise Error, "Clash subscription registry is not safely parseable: #{error.class}"
    end

    def remote_entries(items)
      entries = items.each_with_object([]) do |item, result|
        next unless item.is_a?(Hash) && item["type"] == "remote"

        name = item["name"]
        uid = item["uid"]
        filename = item["file"]
        unless safe_text?(name) && safe_text?(uid) && safe_filename?(filename)
          raise Error, "remote subscription metadata is malformed"
        end

        result << Entry.new(name: name.freeze, uid: uid.freeze, filename: filename.freeze).freeze
      end
      duplicate_uid = entries.group_by(&:uid).find { |_uid, grouped| grouped.length > 1 }
      raise Error, "remote subscription identifiers are ambiguous" if duplicate_uid

      entries
    end

    def confined_profile_path(filename)
      candidate = File.expand_path(filename, @profiles_root)
      prefix = @profiles_root.end_with?(File::SEPARATOR) ? @profiles_root : @profiles_root + File::SEPARATOR
      raise Error, "subscription cache path escapes the Clash profiles directory" unless candidate.start_with?(prefix)

      candidate
    end

    def safe_filename?(value)
      safe_text?(value) && File.basename(value) == value && value.match?(/\A[A-Za-z0-9._-]+\z/)
    end

    def safe_text?(value, max_bytes = 512)
      value.is_a?(String) && !value.empty? && value.bytesize <= max_bytes && !value.match?(/[[:cntrl:]]/)
    end
  end
end

# frozen_string_literal: true

module IpQuality
  # Reads providers/sources.tsv, the reporter's source catalog, so runner plans
  # disclose exactly the IDs, preset and fallbacks the reporter uses.
  module SourceCatalog
    PATH = File.expand_path("../providers/sources.tsv", __dir__)
    Source = Struct.new(:id, :label, :independent, :disclosure, :target_disclosure)

    SOURCES = File.readlines(PATH, chomp: true, encoding: "UTF-8")
      .reject { |line| line.empty? || line.start_with?("#") }
      .map do |line|
        id, label, independent, disclosure, target = line.split("\t", -1)
        raise "malformed source catalog row: #{id.inspect}" unless target && %w[yes no].include?(independent)

        Source.new(id, label, independent == "yes", disclosure, target == "-" ? disclosure : target).freeze
      end.freeze
    IDS = SOURCES.map(&:id).freeze

    module_function

    # SELECTION is all, independent or validated comma-separated IDs.
    def disclosure_lines(selection, explicit_target:)
      chosen = case selection
               when "all" then SOURCES
               when "independent" then SOURCES.select(&:independent)
               else SOURCES.select { |source| selection.split(",").include?(source.id) }
               end
      chosen.map { |source| "    #{source.label}: #{explicit_target ? source.target_disclosure : source.disclosure}" }
    end
  end
end

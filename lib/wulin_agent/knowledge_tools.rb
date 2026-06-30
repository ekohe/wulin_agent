# frozen_string_literal: true

module WulinAgent
  class KnowledgeTools
    UPSERT_KEYS = %w[key value category scope].freeze
    DELETE_KEYS = %w[key scope].freeze

    class << self
      def build
        [build_search, build_upsert, build_delete]
      end

      private

      def build_search
        ToolSpec.new(
          name: "knowledge_search",
          controller: nil,
          operation: "search",
          description: "Search domain knowledge (acronyms, schema mappings, workflows). " \
                        "Call before querying grids when the user mentions domain terms you do not understand. " \
                        "Omit query (or pass *) to list all entries.",
          mutating: false,
          permission: nil,
          params_schema: {
            properties: {
              query: {
                type: "string",
                description: "Text to search in key or value"
              },
              category: {
                type: "string",
                enum: WulinAgent::Knowledge::CATEGORIES,
                description: "Optional category filter"
              },
              scope: {
                type: "string",
                description: "Optional grid scope (e.g. orders). Returns global entries too."
              }
            }
          },
          callable: ->(params, _user) { search(params) }
        )
      end

      def build_upsert
        ToolSpec.new(
          name: "knowledge_upsert",
          controller: nil,
          operation: "upsert",
          description: "Create or update a domain knowledge entry.",
          mutating: true,
          permission: nil,
          params_schema: {
            properties: {
              key: {type: "string", description: "Short identifier (e.g. NHK, MRL)"},
              value: {type: "string", description: "Definition or mapping"},
              category: {type: "string", enum: WulinAgent::Knowledge::CATEGORIES},
              scope: {type: "string", description: "Optional grid scope (e.g. orders)"}
            },
            required: %w[key value category]
          },
          callable: ->(params, _user) { upsert(params) }
        )
      end

      def build_delete
        ToolSpec.new(
          name: "knowledge_delete",
          controller: nil,
          operation: "delete",
          description: "Delete a domain knowledge entry by key.",
          mutating: true,
          permission: nil,
          params_schema: {
            properties: {
              key: {type: "string"},
              scope: {type: "string", description: "Optional scope; omit for global entries"}
            },
            required: ["key"]
          },
          callable: ->(params, _user) { delete(params) }
        )
      end

      def search(params)
        scope = WulinAgent::Knowledge.all
        scope = scope.by_category(params["category"]) if params["category"].present?
        scope = scope.for_scope(params["scope"]) if params["scope"].present?

        query = params["query"].to_s.strip
        query = nil if query.in?(["*", "%"])
        if query.present?
          q = "%#{WulinAgent::Knowledge.sanitize_sql_like(query)}%"
          scope = scope.where("key ILIKE ? OR value ILIKE ?", q, q)
        end

        scope.order(:key).limit(50).map { |entry| serialize(entry) }
      end

      def upsert(params)
        attrs = params.slice(*UPSERT_KEYS).symbolize_keys
        return {"error" => "key is required"} if attrs[:key].blank?
        return {"error" => "value is required"} if attrs[:value].blank?
        return {"error" => "category is required"} if attrs[:category].blank?

        entry = WulinAgent::Knowledge.upsert_entry(**attrs)
        serialize(entry)
      rescue ActiveRecord::RecordInvalid => e
        {"error" => e.record.errors.full_messages.join(", ")}
      end

      def delete(params)
        key = params["key"]
        return {"error" => "key is required"} if key.blank?

        record = WulinAgent::Knowledge.find_by(key: key, scope: params["scope"].presence)
        return {"error" => "entry not found"} unless record

        record.destroy!
        {"deleted" => key, "scope" => record.scope}
      end

      def serialize(entry)
        entry.as_json(only: %w[key value category scope])
      end
    end
  end
end

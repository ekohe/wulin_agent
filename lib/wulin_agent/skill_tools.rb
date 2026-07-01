# frozen_string_literal: true

module WulinAgent
  class SkillTools
    TOOL_SEQUENCE_SCHEMA = {
      type: "array",
      description: "Optional ordered list of tool steps used to accomplish the task. " \
                    "Each item: {tool, params}.",
      items: {
        type: "object",
        properties: {
          tool: {type: "string", description: "Tool name (e.g. list_records)"},
          params: {type: "object", description: "Arguments passed to the tool", properties: {}}
        },
        required: ["tool"]
      }
    }.freeze

    class << self
      def build
        [build_list, build_read, build_create, build_update, build_delete]
      end

      private

      def build_list
        ToolSpec.new(
          name: "skill_list",
          controller: nil,
          operation: "list",
          description: "List available skills (reusable playbooks). " \
                        "Call skill_read to get a skill's full instructions before following it.",
          mutating: false,
          permission: nil,
          params_schema: {},
          callable: ->(_params, _user) { list }
        )
      end

      def build_read
        ToolSpec.new(
          name: "skill_read",
          controller: nil,
          operation: "read",
          description: "Read a skill's full markdown instructions by name.",
          mutating: false,
          permission: nil,
          params_schema: {
            properties: {
              name: {type: "string", description: "Skill name from skill_list"}
            },
            required: ["name"]
          },
          callable: ->(params, _user) { read(params) }
        )
      end

      def build_create
        ToolSpec.new(
          name: "skill_create",
          controller: nil,
          operation: "create",
          description: "Create a reusable skill (playbook) from a successful task. " \
                        "Only do this when the user explicitly approves saving the workflow.",
          mutating: true,
          permission: nil,
          params_schema: {
            properties: {
              name: {type: "string", description: "Short unique identifier (snake_case)"},
              description: {type: "string", description: "One line: when to use this skill"},
              instructions: {type: "string", description: "Markdown playbook the agent will follow"},
              tool_sequence: TOOL_SEQUENCE_SCHEMA
            },
            required: %w[name description instructions]
          },
          callable: ->(params, user) { create(params, user) }
        )
      end
      
      def build_update
        ToolSpec.new(
          name: "skill_update",
          controller: nil,
          operation: "update",
          description: "Update an existing skill by name.",
          mutating: true,
          permission: nil,
          params_schema: {
            properties: {
              name: {type: "string", description: "Name of the skill to update"},
              description: {type: "string"},
              instructions: {type: "string"},
              tool_sequence: TOOL_SEQUENCE_SCHEMA
            },
            required: ["name"]
          },
          callable: ->(params, _user) { update(params) }
        )
      end
      
      def build_delete
        ToolSpec.new(
          name: "skill_delete",
          controller: nil,
          operation: "delete",
          description: "Delete a skill by name. Only do this when the user explicitly asks to remove it.",
          mutating: true,
          permission: nil,
          params_schema: {
            properties: {
              name: {type: "string", description: "Name of the skill to delete"}
            },
            required: ["name"]
          },
          callable: ->(params, _user) { delete(params) }
        )
      end

      def create(params, user = nil)
        skill = WulinAgent::Skill.new(
          name: params["name"],
          description: params["description"],
          instructions: params["instructions"],
          tool_sequence: params["tool_sequence"] || [],
          created_by: user&.id
        )
        skill.save!
        detail(skill)
      rescue ActiveRecord::RecordInvalid => e
        {"error" => e.record.errors.full_messages.join(", ")}
      end
      
      def update(params)
        skill = WulinAgent::Skill.find_by("name ILIKE ?", params["name"])
        return {"error" => "skill not found"} unless skill
      
        attrs = params.slice("description", "instructions", "tool_sequence").compact
        skill.update!(attrs)
        detail(skill)
      rescue ActiveRecord::RecordInvalid => e
        {"error" => e.record.errors.full_messages.join(", ")}
      end

      def delete(params)
        skill = WulinAgent::Skill.find_by("name ILIKE ?", params["name"])
        return {"error" => "skill not found"} unless skill

        skill.destroy!
        {"deleted" => skill.name}
      end

      def list
        WulinAgent::Skill.order(:name).limit(50).map { |skill| summary(skill) }
      end

      def read(params)
        name = params["name"]
        return {"error" => "name is required"} if name.blank?

        skill = WulinAgent::Skill.find_by("name ILIKE ?", name)
        return {"error" => "skill not found"} unless skill

        skill.increment!(:usage_count)
        detail(skill)
      end

      def summary(skill)
        skill.as_json(only: %w[name description usage_count])
      end

      def detail(skill)
        skill.as_json(only: %w[name description instructions usage_count tool_sequence])
      end
    end
  end
end
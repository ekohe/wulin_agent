# frozen_string_literal: true

module WulinAgent
  class SkillTools
    class << self
      def build
        [build_list, build_read, build_create, build_update]
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
              instructions: {type: "string", description: "Markdown playbook the agent will follow"}
            },
            required: %w[name description instructions]
          },
          callable: ->(params, _user) { create(params) }
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
              instructions: {type: "string"}
            },
            required: ["name"]
          },
          callable: ->(params, _user) { update(params) }
        )
      end
      
      def create(params)
        skill = Agent::Skill.new(
          name: params["name"],
          description: params["description"],
          instructions: params["instructions"]
        )
        skill.save!
        detail(skill)
      rescue ActiveRecord::RecordInvalid => e
        {"error" => e.record.errors.full_messages.join(", ")}
      end
      
      def update(params)
        skill = Agent::Skill.find_by("name ILIKE ?", params["name"])
        return {"error" => "skill not found"} unless skill
      
        attrs = params.slice("description", "instructions").compact
        skill.update!(attrs)
        detail(skill)
      rescue ActiveRecord::RecordInvalid => e
        {"error" => e.record.errors.full_messages.join(", ")}
      end

      def list
        Agent::Skill.order(:name).limit(50).map { |skill| summary(skill) }
      end

      def read(params)
        name = params["name"]
        return {"error" => "name is required"} if name.blank?

        skill = Agent::Skill.find_by("name ILIKE ?", name)
        return {"error" => "skill not found"} unless skill

        skill.increment!(:usage_count)
        detail(skill)
      end

      def summary(skill)
        skill.as_json(only: %w[name description usage_count])
      end

      def detail(skill)
        skill.as_json(only: %w[name description instructions usage_count])
      end
    end
  end
end
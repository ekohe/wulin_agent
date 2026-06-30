# frozen_string_literal: true

require "rails_helper"
require "ruby_llm"

RSpec.describe WulinAgent::SkillDistiller do
  let(:user) { User.create!(email: "distill-#{SecureRandom.hex(4)}@example.com", admin: true) }
  let(:conversation) { WulinAgent::Conversation.create!(user: user) }

  let(:message) do
    conversation.messages.create!(role: "user", content: "Show people named Martin")
    conversation.messages.create!(
      role: "assistant",
      content: "Here they are",
      metadata: {
        "tool_calls" => [{"id" => "1", "name" => "list_records", "arguments" => {"controller" => "people"}}],
        "tool_results" => [{"id" => "1", "result" => [{"id" => 1}]}]
      }
    )
  end

  def stub_llm(content)
    chat = instance_double("RubyLLM::Chat")
    reply = instance_double("RubyLLM::Message", content: content)
    allow(RubyLLM).to receive(:chat).and_return(chat)
    allow(chat).to receive(:with_instructions).and_return(chat)
    allow(chat).to receive(:ask).and_return(reply)
    chat
  end

  it "creates a skill from the message tool sequence when reusable" do
    stub_llm('{"reusable": true, "name": "List People", "description": "Find people", "instructions": "1. list_records"}')

    skill = nil
    expect {
      skill = described_class.call(message: message, user: user)
    }.to change(WulinAgent::Skill, :count).by(1)

    expect(skill.name).to eq("list_people")
    expect(skill.description).to eq("Find people")
    expect(skill.tool_sequence).to eq([{"tool" => "list_records", "params" => {"controller" => "people"}}])
    expect(skill.created_by).to eq(user.id)
  end

  it "deduplicates the name when it already exists" do
    WulinAgent::Skill.create!(name: "list_people", description: "d", instructions: "i")
    stub_llm('{"reusable": true, "name": "List People", "description": "d", "instructions": "i"}')

    skill = described_class.call(message: message, user: user)

    expect(skill.name).to eq("list_people_2")
  end

  it "strips markdown fences around the JSON reply" do
    stub_llm("```json\n{\"reusable\": true, \"name\": \"fenced\", \"description\": \"d\", \"instructions\": \"i\"}\n```")

    skill = described_class.call(message: message, user: user)

    expect(skill.name).to eq("fenced")
  end

  it "returns nil and creates nothing when the model says not reusable" do
    stub_llm('{"reusable": false}')

    expect {
      expect(described_class.call(message: message, user: user)).to be_nil
    }.not_to change(WulinAgent::Skill, :count)
  end

  it "returns nil when the model reply is not valid JSON" do
    stub_llm("sorry, no json here")

    expect(described_class.call(message: message, user: user)).to be_nil
  end

  it "returns nil without calling the model when there are no tool steps" do
    empty = conversation.messages.create!(role: "assistant", content: "Just text", metadata: {})

    expect(RubyLLM).not_to receive(:chat)
    expect(described_class.call(message: empty, user: user)).to be_nil
  end
end

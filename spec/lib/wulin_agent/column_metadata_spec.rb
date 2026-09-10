# frozen_string_literal: true

require "active_model"
require "wulin_agent/column_descriptor"
require "wulin_agent/model_naming"
require "wulin_agent/column_metadata"

RSpec.describe WulinAgent::ColumnMetadata do
  let(:schedule_class) do
    Class.new do
      def self.model_name
        ActiveModel::Name.new(self, nil, "Schedule")
      end
    end
  end

  let(:reflection) do
    instance_double(
      "ActiveRecord::Reflection::BelongsToReflection",
      foreign_key: "schedule_id",
      klass: schedule_class
    )
  end

  let(:belongs_to_column) do
    WulinAgent::ColumnDescriptor.new(
      name: :schedule,
      label: "Schedule",
      sql_type: :belongs_to,
      filterable: true,
      sortable: true,
      choices: "/fetch_options?controller=schedules"
    )
  end

  let(:string_column) do
    WulinAgent::ColumnDescriptor.new(
      name: :name,
      label: "Name",
      sql_type: :string,
      filterable: true,
      sortable: true
    )
  end

  let(:model) do
    double("Routine", reflect_on_association: reflection)
  end

  before do
    allow(model).to receive(:reflect_on_association).with(:schedule).and_return(reflection)
  end

  describe ".serialize" do
    it "adds FK metadata for belongs_to columns" do
      result = described_class.serialize(belongs_to_column, model: model)

      expect(result).to include(
        name: "schedule",
        sql_type: "belongs_to",
        foreign_key: "schedule_id",
        lookup_controller: "schedules"
      )
      expect(result[:value_hint]).to include("schedule_id")
      expect(result[:value_hint]).to include('list_records on "schedules"')
    end

    it "uses column.reflection when present" do
      column = belongs_to_column.dup
      column.reflection = reflection

      expect(model).not_to receive(:reflect_on_association)
      described_class.serialize(column, model: model)
    end

    it "returns base payload only for non-belongs_to columns" do
      result = described_class.serialize(string_column, model: model)

      expect(result).to eq(
        name: "name",
        label: "Name",
        sql_type: "string",
        filterable: true,
        sortable: true
      )
      expect(result).not_to have_key(:foreign_key)
    end

    it "returns base payload when belongs_to has no reflection" do
      result = described_class.serialize(belongs_to_column, model: nil)

      expect(result[:sql_type]).to eq("belongs_to")
      expect(result).not_to have_key(:foreign_key)
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ControllerResolver do
  before do
    WulinAgent::Catalog.reset!
    load_dummy_grids
  end

  after do
    WulinMaster::Grid.grids.replace([PersonGrid])
    WulinMaster::Screen.screens&.replace([PersonScreen])
    WulinAgent::Catalog.reset!
    described_class.reset!
  end

  describe ".for_grid" do
    it "resolves PeopleController from PersonGrid via route and plural" do
      expect(described_class.for_grid(PersonGrid)).to eq(PeopleController)
    end

    context "when the grid declares controller_class" do
      let(:story_model) do
        Class.new do
          def self.model_name
            ActiveModel::Name.new(self, nil, "Story")
          end
        end
      end

      let(:story_grid) do
        Class.new(WulinMaster::Grid) do
          def self.model
            Story
          end
        end
      end

      before do
        stub_const("Story", story_model)
        stub_const(
          "Admin::StoriesController",
          Class.new(WulinMaster::ScreenController)
        )
        stub_const("StoryGrid", story_grid)
        StoryGrid.controller_class = Admin::StoriesController
        WulinMaster::Grid.grids.replace([PersonGrid, StoryGrid])
      end

      it "uses the explicit controller_class" do
        expect(described_class.for_grid(StoryGrid)).to eq(Admin::StoriesController)
      end
    end

    context "when a namespaced controller matches the model plural" do
      let(:story_model) do
        Class.new do
          def self.model_name
            ActiveModel::Name.new(self, nil, "Story")
          end
        end
      end

      let(:story_grid) do
        Class.new(WulinMaster::Grid) do
          def self.model
            Story
          end
        end
      end

      let(:event_screen) do
        Class.new(WulinMaster::Screen) do
          path "/admin/events"
          grid EventGrid
          grid StoryGrid, master_grid: "EventGrid"
        end
      end

      before do
        stub_const("Story", story_model)
        stub_const("Event", Class.new { def self.model_name = ActiveModel::Name.new(self, nil, "Event") })
        stub_const("StoryGrid", story_grid)
        stub_const("EventGrid", Class.new(WulinMaster::Grid) { def self.model = Event })
        stub_const("EventScreen", event_screen)
        stub_const(
          "Admin::StoriesController",
          Class.new(WulinMaster::ScreenController)
        )
        stub_const(
          "Admin::EventsController",
          Class.new(WulinMaster::ScreenController) do
            controller_for_screen EventScreen
          end
        )

        WulinMaster::Grid.grids.replace([PersonGrid, EventGrid, StoryGrid])
        WulinMaster::Screen.screens.replace([EventScreen])
      end

      it "prefers the controller whose name matches the model plural" do
        expect(described_class.for_grid(StoryGrid)).to eq(Admin::StoriesController)
      end
    end

    context "when the grid path matches a route" do
      let(:article_model) do
        Class.new do
          def self.model_name
            ActiveModel::Name.new(self, nil, "Article")
          end
        end
      end

      let(:article_grid) do
        Class.new(WulinMaster::Grid) do
          def self.model
            Article
          end
        end
      end

      before do
        stub_const("Article", article_model)
        stub_const("ArticleGrid", article_grid)
        ArticleGrid.path "/people"
        stub_const(
          "Admin::ArticleDetailsController",
          Class.new(WulinMaster::ScreenController)
        )

        WulinMaster::Grid.grids.replace([PersonGrid, ArticleGrid])
      end

      it "resolves via the grid path before the model plural" do
        expect(described_class.for_grid(ArticleGrid)).to eq(PeopleController)
      end
    end

    it "returns nil when no controller can be resolved" do
      orphan_model = Class.new do
        def self.model_name
          ActiveModel::Name.new(self, nil, "Orphan")
        end
      end
      orphan_grid = Class.new(WulinMaster::Grid) do
        def self.model
          OrphanModel
        end
      end

      stub_const("OrphanModel", orphan_model)
      stub_const("OrphanGrid", orphan_grid)
      OrphanGrid.path "/no/such/route"

      expect(described_class.for_grid(orphan_grid)).to be_nil
    end
  end

  describe ".for_name" do
    it "resolves via Catalog descriptor" do
      expect(described_class.for_name("people")).to eq(PeopleController)
    end

    it "returns nil when the grid is not in the catalog" do
      allow(WulinAgent::Catalog).to receive(:find).with("people").and_return(nil)

      expect(described_class.for_name("people")).to be_nil
    end

    it "returns nil when the controller cannot be resolved" do
      orphan_model = Class.new do
        def self.model_name
          ActiveModel::Name.new(self, nil, "Orphan")
        end
      end
      orphan_grid = Class.new(WulinMaster::Grid) do
        def self.model
          OrphanModel
        end
      end

      stub_const("OrphanModel", orphan_model)
      stub_const("OrphanGrid", orphan_grid)
      OrphanGrid.path "/no/such/route"
      WulinMaster::Grid.grids.replace([PersonGrid, OrphanGrid])
      WulinAgent::Catalog.reset!

      expect(described_class.for_name("orphans")).to be_nil
    end
  end
end

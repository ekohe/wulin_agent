# frozen_string_literal: true

require "rails_helper"

RSpec.describe WulinAgent::ControllerResolver do
  before do
    WulinAgent::Catalog.reset!
    WulinAgent.controller_namespace = nil
    PersonScreen
    PersonGrid
  end

  after do
    WulinMaster::Grid.grids.replace([PersonGrid])
    WulinMaster::Screen.screens&.replace([PersonScreen])
    WulinAgent::Catalog.reset!
    WulinAgent.controller_namespace = nil
    described_class.reset!
  end

  describe ".for_grid" do
    it "resolves PeopleController from PersonGrid via PersonScreen" do
      expect(described_class.for_grid(PersonGrid)).to eq(PeopleController)
    end

    context "when the grid appears on multiple screens" do
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

      let(:article_screen) do
        Class.new(WulinMaster::Screen) do
          path "/admin/articles"
          grid ArticleGrid
        end
      end

      let(:article_detail_screen) do
        Class.new(WulinMaster::Screen) do
          path "/admin/article_details"
          grid ArticleGrid
        end
      end

      before do
        stub_const("Article", article_model)
        stub_const("ArticleGrid", article_grid)
        stub_const("ArticleScreen", article_screen)
        stub_const("ArticleDetailScreen", article_detail_screen)
        ArticleGrid.path "/admin/articles"

        stub_const(
          "Admin::ArticlesController",
          Class.new(WulinMaster::ScreenController) do
            controller_for_screen ArticleScreen
          end
        )
        stub_const(
          "Admin::ArticleDetailsController",
          Class.new(WulinMaster::ScreenController) do
            controller_for_screen ArticleDetailScreen
          end
        )

        WulinMaster::Grid.grids.replace([PersonGrid, ArticleGrid])
        WulinMaster::Screen.screens.replace([ArticleDetailScreen, ArticleScreen])
      end

      it "prefers the screen whose path matches the grid path" do
        expect(described_class.for_grid(ArticleGrid)).to eq(Admin::ArticlesController)
      end

      it "resolves via controller_for_screen without a configured namespace" do
        WulinAgent.controller_namespace = nil

        expect(described_class.for_grid(ArticleGrid)).to eq(Admin::ArticlesController)
      end
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
        stub_const(
          "Admin::EventsController",
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

    context "when no controller matches the model plural" do
      let(:chapter_model) do
        Class.new do
          def self.model_name
            ActiveModel::Name.new(self, nil, "Chapter")
          end
        end
      end

      let(:chapter_grid) do
        Class.new(WulinMaster::Grid) do
          def self.model
            Chapter
          end
        end
      end

      let(:chapter_detail_screen) do
        Class.new(WulinMaster::Screen) do
          path "/admin/chapter_details"
          grid ChapterGrid
        end
      end

      let(:event_screen) do
        Class.new(WulinMaster::Screen) do
          path "/admin/events"
          grid EventGrid
          grid ChapterGrid, master_grid: "EventGrid"
        end
      end

      before do
        stub_const("Chapter", chapter_model)
        stub_const("Event", Class.new { def self.model_name = ActiveModel::Name.new(self, nil, "Event") })
        stub_const("ChapterGrid", chapter_grid)
        stub_const("EventGrid", Class.new(WulinMaster::Grid) { def self.model = Event })
        stub_const("ChapterDetailScreen", chapter_detail_screen)
        stub_const("EventScreen", event_screen)
        stub_const(
          "Admin::ChapterDetailsController",
          Class.new(WulinMaster::ScreenController) do
            controller_for_screen ChapterDetailScreen
          end
        )
        stub_const(
          "Admin::EventsController",
          Class.new(WulinMaster::ScreenController) do
            controller_for_screen EventScreen
          end
        )

        WulinMaster::Grid.grids.replace([PersonGrid, EventGrid, ChapterGrid])
        WulinMaster::Screen.screens.replace([EventScreen, ChapterDetailScreen])
      end

      it "prefers the screen where the grid is master" do
        expect(described_class.for_grid(ChapterGrid)).to eq(Admin::ChapterDetailsController)
      end
    end

    context "with Admin namespace fallback" do
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
        stub_const(
          "Admin::ArticlesController",
          Class.new(WulinMaster::ScreenController)
        )
        WulinAgent.controller_namespace = "Admin"
        WulinMaster::Grid.grids.replace([PersonGrid, ArticleGrid])
      end

      it "constantizes Admin::ArticlesController when no screen is linked" do
        expect(described_class.for_grid(ArticleGrid)).to eq(Admin::ArticlesController)
      end
    end

    it "raises when no controller can be resolved" do
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

      expect { described_class.for_grid(orphan_grid) }
        .to raise_error(NameError, /OrphansController/)
    end
  end

  describe ".for_name" do
    it "resolves via Catalog descriptor" do
      expect(described_class.for_name("people")).to eq(PeopleController)
    end

    it "falls back to constantize when the grid is not in the catalog" do
      allow(WulinAgent::Catalog).to receive(:find).with("people").and_return(nil)

      expect(described_class.for_name("people")).to eq(PeopleController)
    end

    it "raises when the controller name is unknown" do
      allow(WulinAgent::Catalog).to receive(:find).and_return(nil)

      expect { described_class.for_name("nonexistent_things") }
        .to raise_error(NameError, /NonexistentThingsController/)
    end
  end
end

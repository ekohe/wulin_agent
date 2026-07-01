# frozen_string_literal: true

module WulinAgent
  module ModelNaming
    module_function

    def for(model)
      return model.model_name if model.respond_to?(:model_name)

      ActiveModel::Name.new(model, nil, model.name)
    end
  end
end
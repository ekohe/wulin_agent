# frozen_string_literal: true

class PersonGrid < WulinMaster::Grid
  JOBS = %w[Developer DevOps Designer PM].freeze
  title "People"

  model Person

  column :first_name
  column :last_name
  column :age
  column :signature
  column :birthdate
  column :job, choices: JOBS, editor: "SelectEditor"
  column :status, choices: Person.statuses.keys
  column :vip

  action :fullscreen, icon: :fullscreen, global: true
  action :greet, icon: :waving_hand, title: "Greet"
  action :tag, icon: :waving_hand, title: "Tag"

  load_default_actions
end

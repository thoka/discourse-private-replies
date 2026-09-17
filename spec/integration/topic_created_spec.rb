# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

describe 'topic_created discourse event' do
  fab!(:author, :user)
  fab!(:category)

  before { SiteSetting.private_replies_enabled = true }

  def create_topic_in(category)
    title = "Brand new topic in #{category.name}"
    PostCreator.create!(
      author,
      title: title,
      raw: 'This is the body of a brand new topic.',
      category: category.id,
      skip_validations: true,
    )
    Topic.find_by(title: title)
  end

  def private_replies_flag_for(category)
    create_topic_in(category).custom_fields['private_replies']
  end

  it 'switches private replies on when the category default is on' do
    category.upsert_custom_fields('private_replies_default_enabled' => true)
    expect(private_replies_flag_for(category)).to eq(true)
  end

  it 'leaves new topics alone when the category default is off' do
    expect(private_replies_flag_for(category)).to be_falsey
  end

  it 'leaves new topics alone while the plugin is switched off site wide' do
    SiteSetting.private_replies_enabled = false
    category.upsert_custom_fields('private_replies_default_enabled' => true)
    expect(private_replies_flag_for(category)).to be_falsey
  end

  context 'when only selected categories may use private replies' do
    before { SiteSetting.private_replies_on_selected_categories_only = true }

    it 'leaves new topics alone in a category that is not opted in' do
      category.upsert_custom_fields('private_replies_default_enabled' => true)
      expect(private_replies_flag_for(category)).to be_falsey
    end

    it 'switches private replies on in a category that is opted in' do
      category.upsert_custom_fields(
        'private_replies_default_enabled' => true,
        'private_replies_enabled' => true,
      )
      expect(private_replies_flag_for(category)).to eq(true)
    end

    it 'leaves new topics alone in an opted in category without the default' do
      category.upsert_custom_fields('private_replies_enabled' => true)
      expect(private_replies_flag_for(category)).to be_falsey
    end
  end
end

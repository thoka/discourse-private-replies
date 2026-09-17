# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

describe 'TopicViewSerializer private replies fields' do
  fab!(:topic_owner, :user)
  fab!(:viewer, :user)
  fab!(:admin)
  fab!(:topic) { private_replies_topic(user: topic_owner) }

  before do
    SiteSetting.private_replies_enabled = true
    create_posts(topic, [topic_owner, viewer])
  end

  def serialize_for(user)
    topic_view = TopicView.new(topic, user)
    TopicViewSerializer.new(topic_view, scope: Guardian.new(user), root: false).as_json
  end

  context 'when the topic is protected' do
    it 'reports that private replies are on' do
      expect(serialize_for(viewer)[:private_replies]).to eq(true)
    end

    it 'reports limited replies for a viewer who may not see all replies' do
      expect(serialize_for(viewer)[:private_replies_limited]).to eq(true)
    end

    it 'reports unlimited replies for the topic starter' do
      expect(serialize_for(topic_owner)[:private_replies_limited]).to eq(false)
    end

    it 'reports unlimited replies for staff' do
      expect(serialize_for(admin)[:private_replies_limited]).to eq(false)
    end
  end

  context 'when the topic is not protected' do
    before { remove_private_replies(topic) }

    it 'reports that private replies are off' do
      expect(serialize_for(viewer)[:private_replies]).to eq(false)
    end

    it 'does not report anything about limited replies' do
      expect(serialize_for(viewer).keys).not_to include(:private_replies_limited)
    end
  end

  context 'when private replies is switched off site wide' do
    before { SiteSetting.private_replies_enabled = false }

    it 'does not report anything about limited replies' do
      expect(serialize_for(viewer).keys).not_to include(:private_replies_limited)
    end
  end
end

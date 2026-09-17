# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

describe TopicViewDetailsSerializer do
  fab!(:topic_owner, :user)
  fab!(:viewer, :user)
  fab!(:hidden_user, :user)
  fab!(:allowed_user, :user)
  fab!(:admin)
  fab!(:topic) { private_replies_topic(user: topic_owner) }

  before { SiteSetting.private_replies_enabled = true }

  def last_poster_for(user)
    topic_view = TopicView.new(topic, user)
    TopicViewDetailsSerializer.new(topic_view, scope: Guardian.new(user), root: false).last_poster
  end

  context 'when the last poster is someone the viewer may not see' do
    before { create_posts(topic, [topic_owner, hidden_user]) }

    it 'shows the topic starter to a regular viewer' do
      expect(last_poster_for(viewer)&.id).to eq(topic_owner.id)
    end

    it 'shows the topic starter to anonymous visitors' do
      expect(last_poster_for(nil)&.id).to eq(topic_owner.id)
    end

    it 'shows the real last poster to the topic starter' do
      expect(last_poster_for(topic_owner)&.id).to eq(hidden_user.id)
    end

    it 'shows the real last poster to staff' do
      expect(last_poster_for(admin)&.id).to eq(hidden_user.id)
    end
  end

  context 'when the last poster is someone the viewer may see' do
    before do
      group = Fabricate(:group)
      SiteSetting.private_replies_see_all_from_groups = group.id.to_s
      group.users << allowed_user
      create_posts(topic, [topic_owner, allowed_user])
    end

    it 'shows the real last poster' do
      expect(last_poster_for(viewer)&.id).to eq(allowed_user.id)
    end
  end

  context 'when the topic is not protected' do
    before do
      remove_private_replies(topic)
      create_posts(topic, [topic_owner, hidden_user])
    end

    it 'shows the real last poster' do
      expect(last_poster_for(viewer)&.id).to eq(hidden_user.id)
    end
  end

  context 'when private replies is switched off site wide' do
    before do
      SiteSetting.private_replies_enabled = false
      create_posts(topic, [topic_owner, hidden_user])
    end

    it 'shows the real last poster' do
      expect(last_poster_for(viewer)&.id).to eq(hidden_user.id)
    end
  end
end

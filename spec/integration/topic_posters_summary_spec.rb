# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

describe TopicPostersSummary do
  fab!(:topic_owner, :user)
  fab!(:hidden_user, :user)
  fab!(:topic) { private_replies_topic(user: topic_owner) }

  before do
    SiteSetting.private_replies_enabled = true
    create_posts(topic, [topic_owner, hidden_user])
  end

  def summary_user_ids
    TopicPostersSummary.new(topic, {}).summary.map { |poster| poster.user.id }
  end

  context 'when the topic is not protected' do
    before { remove_private_replies(topic) }

    it 'keeps every poster' do
      expect(summary_user_ids).to contain_exactly(topic_owner.id, hidden_user.id)
    end
  end

  context 'when private replies is switched off site wide' do
    before { SiteSetting.private_replies_enabled = false }

    it 'keeps every poster' do
      expect(summary_user_ids).to contain_exactly(topic_owner.id, hidden_user.id)
    end
  end

  context 'when the topic is protected' do
    it 'keeps the topic starter' do
      expect(summary_user_ids).to include(topic_owner.id)
    end

    it 'removes users whose posts are hidden' do
      expect(summary_user_ids).not_to include(hidden_user.id)
    end

    # NOTE: core never hands TopicPostersSummary the user that is looking at the
    # topic list, so the plugin has to remove every poster that is not visible to
    # everybody, and it cannot keep the posters that the current viewer *is*
    # allowed to see (their own posts, or posts of a group that may see all).
    # Pinned here so a change in that behaviour is noticed.
    it 'removes every poster whose posts are not visible to everybody' do
      expect(summary_user_ids).to contain_exactly(topic_owner.id)
    end
  end
end

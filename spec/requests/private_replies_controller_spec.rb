# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

describe 'PrivateRepliesController' do
  fab!(:topic_owner, :user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:member, :user)
  fab!(:topic) { Fabricate(:topic, user: topic_owner) }

  before { SiteSetting.private_replies_enabled = true }

  def enable_for(user)
    sign_in(user) if user
    put '/private_replies/enable.json', params: { topic_id: topic.id }
  end

  def disable_for(user)
    sign_in(user) if user
    put '/private_replies/disable.json', params: { topic_id: topic.id }
  end

  def private_replies_flag
    topic.reload.custom_fields['private_replies']
  end

  describe 'PUT /private_replies/enable' do
    it 'lets the topic starter switch private replies on' do
      enable_for(topic_owner)
      expect(response.status).to eq(200)
      expect(response.parsed_body['private_replies_enabled']).to eq(true)
      expect(private_replies_flag).to eq(true)
    end

    it 'lets an admin switch private replies on' do
      enable_for(admin)
      expect(response.status).to eq(200)
      expect(private_replies_flag).to eq(true)
    end

    it 'lets a moderator switch private replies on' do
      enable_for(moderator)
      expect(response.status).to eq(200)
      expect(private_replies_flag).to eq(true)
    end

    it 'refuses a member who did not start the topic' do
      enable_for(member)
      expect(response.status).to eq(403)
      expect(private_replies_flag).to be_falsey
    end

    it 'refuses anonymous visitors' do
      enable_for(nil)
      expect(response.status).to eq(403)
      expect(private_replies_flag).to be_falsey
    end

    it 'returns 404 for a topic that does not exist' do
      sign_in(topic_owner)
      put '/private_replies/enable.json', params: { topic_id: -1 }
      expect(response.status).to eq(404)
    end

    context 'when private replies is switched off site wide' do
      before { SiteSetting.private_replies_enabled = false }

      # the whole controller is blocked by requires_plugin while the plugin is off
      it 'refuses the topic starter' do
        enable_for(topic_owner)
        expect(response.status).to eq(404)
        expect(private_replies_flag).to be_falsey
      end

      it 'refuses staff' do
        enable_for(admin)
        expect(response.status).to eq(404)
        expect(private_replies_flag).to be_falsey
      end
    end

    context 'when only selected categories may use private replies' do
      before { SiteSetting.private_replies_on_selected_categories_only = true }

      it 'refuses topics in a category that is not opted in' do
        enable_for(topic_owner)
        expect(response.status).to eq(403)
        expect(private_replies_flag).to be_falsey
      end

      it 'allows topics in a category that is opted in' do
        topic.category.upsert_custom_fields('private_replies_enabled' => true)
        enable_for(topic_owner)
        expect(response.status).to eq(200)
        expect(private_replies_flag).to eq(true)
      end
    end
  end

  describe 'PUT /private_replies/disable' do
    before { switch_private_replies_on(topic) }

    it 'lets the topic starter switch private replies off' do
      disable_for(topic_owner)
      expect(response.status).to eq(200)
      expect(response.parsed_body['private_replies_enabled']).to eq(false)
      expect(private_replies_flag).to be_falsey
    end

    it 'lets staff switch private replies off' do
      disable_for(admin)
      expect(response.status).to eq(200)
      expect(private_replies_flag).to be_falsey
    end

    it 'refuses a member who did not start the topic' do
      disable_for(member)
      expect(response.status).to eq(403)
      expect(private_replies_flag).to eq(true)
    end
  end
end

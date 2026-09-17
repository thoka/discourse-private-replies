# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

# Profile -> Activity. `UserAction.stream` builds its SQL through the class
# method `apply_common_filters`, which the plugin patches on the singleton class.
describe UserAction do
  fab!(:topic_owner, :user)
  fab!(:viewer, :user)
  fab!(:hidden_user, :user)
  fab!(:allowed_user, :user)
  fab!(:protected_topic) { private_replies_topic(user: topic_owner) }
  fab!(:public_topic) { Fabricate(:topic, user: topic_owner) }

  before do
    SiteSetting.private_replies_enabled = true
    @protected_post = Fabricate(:post, topic: protected_topic, user: hidden_user)
    @public_post = Fabricate(:post, topic: public_topic, user: hidden_user)
  end

  def action_for(post)
    UserAction.log_action!(
      action_type: UserAction::REPLY,
      user_id: hidden_user.id,
      acting_user_id: hidden_user.id,
      target_topic_id: post.topic_id,
      target_post_id: post.id,
    )
    UserAction.find_by(target_post_id: post.id)
  end

  # `UserAction.stream` returns rows, not records, so compare ids.
  def stream_ids_for(user)
    UserAction.stream(user_id: hidden_user.id, guardian: Guardian.new(user)).map(&:id)
  end

  it 'keeps replies in protected topics out of other people their activity' do
    protected_action = action_for(@protected_post)
    public_action = action_for(@public_post)

    ids = stream_ids_for(viewer)
    expect(ids).to include(public_action.id)
    expect(ids).not_to include(protected_action.id)
  end

  it 'keeps them in the activity of the author' do
    protected_action = action_for(@protected_post)
    expect(stream_ids_for(hidden_user)).to include(protected_action.id)
  end

  it 'keeps them in the activity for the topic starter' do
    protected_action = action_for(@protected_post)
    expect(stream_ids_for(topic_owner)).to include(protected_action.id)
  end

  it 'keeps them in the activity for users that may see all replies' do
    protected_action = action_for(@protected_post)
    group = Fabricate(:group)
    group.users << allowed_user
    SiteSetting.private_replies_groups_can_see_all = group.id.to_s

    expect(stream_ids_for(allowed_user)).to include(protected_action.id)
  end

  it 'keeps them in the activity for staff' do
    protected_action = action_for(@protected_post)
    expect(stream_ids_for(Fabricate(:moderator))).to include(protected_action.id)
  end


  it 'hides them from anonymous visitors without breaking' do
    protected_action = action_for(@protected_post)
    ids = nil

    expect { ids = stream_ids_for(nil) }.not_to raise_error
    expect(ids).not_to include(protected_action.id)
  end

  it 'does not filter while the plugin is disabled' do
    protected_action = action_for(@protected_post)
    SiteSetting.private_replies_enabled = false

    expect(stream_ids_for(viewer)).to include(protected_action.id)
  end
end

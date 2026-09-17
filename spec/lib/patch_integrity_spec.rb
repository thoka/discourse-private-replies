# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/private_replies_helpers'

# Guards the way this plugin patches core. `alias_method` copies whatever happens
# to be first in the ancestor chain at the moment it runs, so when two plugins
# patch the same method they can end up calling each other and blow the stack.
# Prepended modules that call `super` don't have that problem.
describe DiscoursePrivateReplies do
  fab!(:topic_owner, :user)
  fab!(:viewer, :user)
  fab!(:hidden_user, :user)
  fab!(:topic) { private_replies_topic(user: topic_owner) }

  before do
    SiteSetting.private_replies_enabled = true
    create_posts(topic, [topic_owner, hidden_user])
  end

  def patch_index(ancestors, name)
    ancestors.index { |mod| mod.name&.split('::')&.last == name }
  end

  it 'prepends the post guardian patch ahead of the core module' do
    ancestors = PostGuardian.ancestors
    ours = patch_index(ancestors, 'PrivateRepliesPostGuardian')
    core = ancestors.index(PostGuardian)

    # other plugins may be prepended in front of ours, so only check that we are
    # in front of the module we are patching
    expect(ours).not_to be_nil
    expect(ours).to be < core
  end

  it 'prepends the topic class patch ahead of the core class' do
    ancestors = Topic.singleton_class.ancestors
    ours = patch_index(ancestors, 'PrivateRepliesTopicClassMethods')
    core = ancestors.index(Topic.singleton_class)

    expect(ours).not_to be_nil
    expect(ours).to be < core
  end

  it 'does not keep copies of the original methods around' do
    expect(PostGuardian.method_defined?(:org_can_see_post?)).to eq(false)
    expect(Topic.singleton_class.method_defined?(:original_for_digest_private_replies)).to eq(false)
  end

  it 'does not use alias_method to patch' do
    source = File.read(File.expand_path('../../plugin.rb', __dir__))

    expect(source).not_to include('alias_method')
  end

  it 'keeps both patch and core behaviour when another plugin prepends to PostGuardian' do
    probe =
      Module.new do
        def can_see_post?(post)
          return false if post.raw == 'This post is blocked by the probe.'
          super
        end
      end
    PostGuardian.prepend(probe)

    blocked_post = Fabricate(:post, topic: topic, user: topic_owner, raw: 'This post is blocked by the probe.')
    visible_post = Fabricate(:post, topic: topic, user: topic_owner)
    hidden_post = Fabricate(:post, topic: topic, user: hidden_user)
    guardian = Guardian.new(viewer)

    expect(guardian.can_see_post?(blocked_post)).to eq(false) # the other plugin wins
    expect(guardian.can_see_post?(visible_post)).to eq(true)  # core still runs
    expect(guardian.can_see_post?(hidden_post)).to eq(false)  # this plugin still runs
  end

  it 'keeps both patch and core behaviour when another plugin prepends to the topic class' do
    probe = Module.new { def for_digest(user, since, opts = nil) = super }
    Topic.singleton_class.prepend(probe)

    expect { Topic.for_digest(viewer, 1.day.ago).to_a }.not_to raise_error
  end
end

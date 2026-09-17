# frozen_string_literal: true

# Helpers shared by the private replies specs.
module PrivateRepliesHelpers
  # Fabricates a topic that has private replies switched on.
  def private_replies_topic(user: Fabricate(:user), **options)
    topic = Fabricate(:topic, user: user, **options)
    switch_private_replies_on(topic)
    topic
  end

  # Switches private replies on for a topic, the same way the plugin does it.
  def switch_private_replies_on(topic)
    topic.custom_fields['private_replies'] = true
    topic.save_custom_fields
    topic.reload
  end

  # Switches private replies off again for a topic.
  def remove_private_replies(topic)
    TopicCustomField.where(topic_id: topic.id, name: 'private_replies').delete_all
    topic.custom_fields.delete('private_replies')
    topic.reload
  end

  # Creates one post per user through the real post creator, so that topic
  # statistics (last poster and friends) are updated the way they are in
  # production. Returns the posts.
  def create_posts(topic, users)
    posts =
      users.map do |user|
        PostCreator.create!(
          user,
          topic_id: topic.id,
          raw: "This is a reply by #{user.username} in the topic under test.",
        )
      end
    topic.reload
    posts
  end

  # Writes the raw custom field value, e.g. "true" as written by the API,
  # instead of the "t" that Discourse itself writes for booleans.
  def set_raw_private_replies_value(topic, value)
    TopicCustomField.where(topic_id: topic.id, name: 'private_replies').delete_all
    TopicCustomField.create!(topic_id: topic.id, name: 'private_replies', value: value)
    topic.reload
  end
end

RSpec.configure { |config| config.include PrivateRepliesHelpers }

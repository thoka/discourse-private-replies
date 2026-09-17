# frozen_string_literal: true

module DiscoursePrivateReplies
  class PrivateRepliesController < ApplicationController
    requires_plugin 'discourse-private-replies'
    requires_login

    def enable
      t = Topic.find(params[:topic_id])
      if allowed_to_toggle?(t)
        t.custom_fields['private_replies'] = true
        t.save!
        render json: { private_replies_enabled: true }
      else
        render json: { failed: 'Access denied' }, status: :forbidden
      end
    end

    def disable
      t = Topic.find(params[:topic_id])
      if allowed_to_toggle?(t)
        t.custom_fields['private_replies'] = false
        t.save!
        render json: { private_replies_enabled: false }
      else
        render json: { failed: 'Access denied' }, status: :forbidden
      end
    end

    private

    def allowed_to_toggle?(topic)
      allowed_for_category(topic) && ((current_user.id == topic.user_id) || current_user.staff?)
    end

    def allowed_for_category(topic)
      (SiteSetting.private_replies_on_selected_categories_only == false) || (topic&.category&.custom_fields&.dig('private_replies_enabled') || false)
    end

  end
end


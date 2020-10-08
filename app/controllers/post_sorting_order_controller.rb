# frozen_string_literal: true
class DiscoursePostSortingCustomizer::PostSortingOrderController < ::ApplicationController
  def sortby
    post_tab = params[:post_tab]
    data = { post_tab: post_tab }
    if current_user
      user = current_user
      user.custom_fields[:sort_order] = post_tab
      user.save_custom_fields(true)
      MessageBus.publish('/post-sort-update', data, user_ids: [user.id])
    else
      MessageBus.publish('/post-sort-update', data, user_ids: [])
    end
    render json: MultiJson.dump(success_json)
  end
end

# frozen_string_literal: true

# name: discourse-post-sorting-customizer-enabled
# about: sorting posts based on given parameters
# version: 0.1
# authors: Jahan Gagan

enabled_site_setting :discourse_post_sorting_customizer_enabled

PLUGIN_NAME ||= 'DiscoursePostSortingCustomizer'

register_asset 'stylesheets/desktop/post-sorting-buttons.scss', :desktop
register_asset 'stylesheets/mobile/post-sorting-buttons.scss', :mobile
gem 'request_store', '1.5.0', require: true

after_initialize do
  add_to_serializer(:basic_user, :post_tab) do
    user.custom_fields['sort_order']
  end

  module ::DiscoursePostSortingCustomizer
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePostSortingCustomizer
    end
  end

  module TopicViewCustomExtension
    def initialize(topic_or_topic_id, user = nil, options = {})
      super
      sort_by = user ? user.custom_fields['sort_order'] : ::RequestStore.store[:post_tab]
      return if sort_by.nil?
      @posts = @posts.reorder('')
      first_post = @posts.first
      remaining_posts = @posts.where.not(id: @posts.first.id)
      case sort_by
      when "likes"
        @posts = first_post + remaining_posts.order(like_count: :desc)
      when "active"
        @posts = first_post + remaining_posts.order(created_at: :desc)
      else
        @posts = first_post + remaining_posts.order(:created_at)
      end
    end
  end
  ::TopicView.prepend TopicViewCustomExtension

  module ::TopicsControllerExtension
    def show
      ::RequestStore.store[:post_tab] = cookies[:post_tab]
      super
    end
  end
  ::TopicsController.prepend ::TopicsControllerExtension

  require File.expand_path('../app/controllers/post_sorting_order_controller.rb', __FILE__)
  DiscoursePostSortingCustomizer::Engine.routes.draw do
    post '/post-tab/' => 'post_sorting_order#sortby'
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePostSortingCustomizer::Engine, at: '/'
  end

end

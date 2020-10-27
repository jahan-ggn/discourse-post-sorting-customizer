# frozen_string_literal: true

# name: discourse-post-sorting-customizer
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
    user.custom_fields['post_tab']
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
      sort_by = user ? user.custom_fields['post_tab'] : ::RequestStore.store[:post_tab]
      return if sort_by.nil?
      @posts = @posts.reorder('')
      first_post = @posts.where(id: @posts.first.id)
      if SiteSetting.respond_to?(:solved_enabled) && SiteSetting.solved_enabled
        solution_post_id = TopicCustomField.where(topic_id: topic_or_topic_id).where(name: "accepted_answer_post_id").pluck(:value).join.to_i
        solution_post = @posts.where(id: solution_post_id)
        remaining_posts = @posts.where.not(id: @posts.first.id).where.not(id: solution_post_id)
        case sort_by
        when "likes"
          @posts = first_post + solution_post + remaining_posts.order(like_count: :desc)
        when "active"
          @posts = first_post + solution_post + remaining_posts.order(created_at: :desc)
        else
          @posts = first_post + solution_post + remaining_posts.order(:created_at)
        end
      else
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
  end
  ::TopicView.prepend TopicViewCustomExtension

  module ::TopicsControllerExtension
    def show
      p params[:post_tab]
      ::RequestStore.store[:post_tab] = params[:post_tab]
      super
    end
  end
  ::TopicsController.prepend ::TopicsControllerExtension

  require File.expand_path('../app/controllers/post_sorting_order_controller.rb', __FILE__)
  DiscoursePostSortingCustomizer::Engine.routes.draw do
    get '/post-tab/' => 'post_sorting_order#sortby'
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePostSortingCustomizer::Engine, at: '/'
  end

end

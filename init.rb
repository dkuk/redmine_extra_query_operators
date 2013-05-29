require 'redmine'
require 'dispatcher' unless Rails::VERSION::MAJOR >= 3

unless Redmine::Plugin.registered_plugins.keys.include?(:redmine_extra_query_operators)
  Redmine::Plugin.register :redmine_extra_query_operators do  	
    name 'Extra query operators plugin'
    author 'Vitaly Klimov'
    author_url 'mailto:vitaly.klimov@snowbirdgames.com'
    description 'Extra query operators plugin for Redmine'
    version '0.1.1'

    requires_redmine :version_or_higher => '1.3.0'
  end
end

if Rails::VERSION::MAJOR >= 3
  ActionDispatch::Callbacks.to_prepare do
    require 'extra_query_operators_patch'
  end
else
  Dispatcher.to_prepare EQO_AssetHelpers::PLUGIN_NAME do
    require_dependency 'extra_query_operators_patch'
  end
end

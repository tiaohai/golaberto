ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => 'home'

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # map championship actions
  map.connect 'championship/show/:id/phases/:phase', :controller => 'championship', :action => 'phases'
  map.connect 'championship/show/:id/phases/:phase/team_json/', :controller => 'championship', :action => 'team_json'
  map.connect 'championship/show/:id/games/:phase', :controller => 'championship', :action => 'games'
  map.connect 'championship/show/:id/new_game/:phase', :controller => 'championship', :action => 'new_game'
  map.connect 'championship/show/:id/team/:team', :controller => 'championship', :action => 'team'

  map.connect 'game/list/:type/:page', :controller => 'game', :action => 'list', :page => /\d+/, :defaults => { :type => 'scheduled', :page => 1 }

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id', :controller => 'home'
end

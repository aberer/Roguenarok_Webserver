ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

#  map.connect ':controller/:action/:id'
#  map.connect ':controller/:action/:id.:format'
#  map.root     :controller => "roguenarok"

  # empty rout
  map.connect '', :controller => "roguenarok", :action => "index"

  # roguenarok as main controller
  map.connect ':action/:id'        , :controller => 'roguenarok'
  map.connect ':action/:id.:format', :controller => 'roguenarok'

  # all other routes
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

end

module TT::Plugins::BitmapToMesh

  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins').add_submenu('Bitmap to Mesh Debug Tools')
    menu.add_item('Profile Heightmap from Selection')  { self.profile_heightmap }

    file_loaded(__FILE__)
  end

  def self.profile_heightmap
    Sketchup.require 'SpeedUp'
    model = Sketchup.active_model
    image = model.selection.grep(Sketchup::Image).first
    tool = self.heightmap_to_mesh(image)
    SpeedUp.profile {
      tool.onUserText(-2.m, model.active_view)
    }
  end

end # module

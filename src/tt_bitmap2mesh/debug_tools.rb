#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/helpers/image'
require 'tt_bitmap2mesh/bitmap'
require 'tt_bitmap2mesh/heightmap'


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

    return UI.beep if image.nil?

    bitmap = Bitmap.from_image(image)
    material = Image.clone_material(image)

    transformation = image.transformation
    height = 2.m

    heightmap = HeightmapMesh.new

    SpeedUp.profile {
      model.start_operation('Mesh From Heightmap', true)
      group = heightmap.generate(model.active_entities, bitmap, height, material, transformation)
      model.commit_operation
    }

  end

end # module

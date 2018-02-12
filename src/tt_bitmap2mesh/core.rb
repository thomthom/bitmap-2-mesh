#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------


# Attempt to load TT_Lib or provide install instructions.
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new(options)
      w.set_size(500, 300)
      w.set_url("#{url}?plugin=#{File.basename( __FILE__ )}")
      w.show
      @lib2_update = w
    end
  end
end


require 'tt_bitmap2mesh/debug'
require 'tt_bitmap2mesh/bitmap'
require 'tt_bitmap2mesh/place_mesh_tool'


if defined?(TT::Lib) && TT::Lib.compatible?('2.7.0', 'Bitmap to Mesh')

module TT::Plugins::BitmapToMesh

  unless file_loaded?(__FILE__)
    menu = UI.menu('Draw')
    menu.add_item('Mesh From Heightmap')  { self.bitmap_to_mesh_tool }

    UI.add_context_menu_handler { |context_menu|
      selection = Sketchup.active_model.selection
      if selection.length == 1 && selection[0].is_a?(Sketchup::Image)
        image = selection[0]
        context_menu.add_item('Mesh From Heightmap') { self.heightmap_to_mesh(image) }
        context_menu.add_item('Mesh From Bitmap')    { self.image_to_mesh(image) }
      end
    }
    file_loaded(__FILE__)
  end


  def self.bitmap_to_mesh_tool
    if defined?(Sketchup::ImageRep)
      filetypes = %w[bmp jpg jpeg png psd tif tga]
      filter = filetypes.map { |filetype| "*.#{filetype}" }.join(';')
      filter = "Image Files|#{filter}||"
      filename = UI.openpanel('Select image file', nil, filter)
    else
      filename = UI.openpanel('Select BMP File', nil, '*.bmp')
    end
    return if filename.nil?
    bitmap = Bitmap.new(filename)
    Sketchup.active_model.tools.push_tool(PlaceMeshTool.new(bitmap))
  end


  def self.heightmap_to_mesh(image)
    bitmap = Bitmap.from_image(image)
    Sketchup.active_model.tools.push_tool(PlaceMeshTool.new(bitmap, image))
  end


  def self.image_to_mesh(image)
    bitmap = Bitmap.from_image(image)
    model = Sketchup.active_model
    model.start_operation('Mesh From Bitmap', true)
    group = model.active_entities.add_group
    group.description = 'Mesh from Bitmap'
    progress = TT::Progressbar.new(bitmap.pixels, 'Mesh from Bitmap')
    group.transform!(self.image_transformation(image))
    bitmap.height.times { |y|
      bitmap.width.times { |x|
        progress.next
        index = (bitmap.width * y) + x
        color = bitmap.data[index]
        points = [
          [x,     y,     0],
          [x + 1, y,     0],
          [x + 1, y + 1, 0],
          [x,     y + 1, 0]
        ]
        face = group.entities.add_face(points)
        # Ensure face's front side is oriented upwards. SketchUp will try to
        # force it to point downwards - preparing it to be push-pulled.
        face.reverse! unless face.normal.samedirection?(Z_AXIS)
        face.material = color
      }
    }
    model.commit_operation
  end


  def self.image_transformation(image)
    if image.respond_to?(:transformation)
      return image.transformation
    end
    # (!) Doesn't handle flipped images correctly.
    origin = image.origin
    axes = image.normal.axes
    x_scale = image.width / image.pixelwidth
    y_scale = image.height / image.pixelheight
    tr_scaling = Geom::Transformation.scaling(ORIGIN, x_scale, y_scale, 1)
    tr_rotation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, image.zrotation)
    tr_axes = Geom::Transformation.axes(origin, axes.x, axes.y, axes.z)
    tr = tr_axes * tr_rotation * tr_scaling
    tr
  end


end # module

end # if TT_Lib

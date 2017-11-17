#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

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
require 'tt_bitmap2mesh/gl_bmp'
require 'tt_bitmap2mesh/place_mesh_tool'


#-------------------------------------------------------------------------------

if defined?(TT::Lib) && TT::Lib.compatible?('2.7.0', 'Bitmap to Mesh')

module TT::Plugins::BitmapToMesh

  ### MENU & TOOLBARS ### --------------------------------------------------

  unless file_loaded?(__FILE__)
    m = TT.menu('Draw')
    m.add_item('Mesh From Heightmap')  { self.bitmap_to_mesh_tool() }

    UI.add_context_menu_handler { |context_menu|
      sel = Sketchup.active_model.selection
      if sel.length == 1 && sel[0].is_a?( Sketchup::Image )
        context_menu.add_item('Mesh From Heightmap')  { self.heightmap_to_mesh }
        context_menu.add_item('Mesh From Bitmap')     { self.image_to_mesh }
      end
    }
  end


  ### MAIN SCRIPT ### ------------------------------------------------------


  def self.image_to_mesh
    temp_path = File.expand_path(TT::System.temp_path)
    temp_file = File.join(temp_path, 'TT_BMP2Mesh.bmp')
    model = Sketchup.active_model
    image = model.selection[0]
    tw = Sketchup.create_texture_writer
    tw.load(image)
    tw.write(image, temp_file)
    dib = GL_BMP.new(temp_file)
    File.delete(temp_file)

    size_x = image.width / image.pixelwidth
    size_y = image.height / image.pixelheight
    model.start_operation('Mesh From Bitmap', true)
      g = model.active_entities.add_group
      g.description = 'Mesh from Bitmap'
      progress = TT::Progressbar.new( dib.pixels, 'Mesh from Bitmap' )
      g.transform!(self.image_transformation(image))
      dib.height.times { |y|
        dib.width.times { |x|
          progress.next
          index = (dib.width * y) + x
          color = dib.data[index]
          # Generate a Point3d from pixel colour.
          left  = x * size_x
          top   = y * size_y
          pts = [
            [left,top,0],
            [left+size_x,top,0],
            [left+size_x,top+size_y,0],
            [left,top+size_y,0]
          ]
          # (!) Detect failed face creation (too small)
          face = g.entities.add_face( pts )
          face.reverse! unless face.normal.samedirection?( Z_AXIS )
          face.material = color
        }
      }
    model.commit_operation
  end


  # (!) Doesn't handle flipped images correctly.
  def self.image_transformation(image)
    origin = image.origin
    axes = image.normal.axes
    tr = Geom::Transformation.axes(ORIGIN, axes.x, axes.y, axes.z)
    tr = tr * Geom::Transformation.rotation(ORIGIN, Z_AXIS, image.zrotation)
    tr = (tr * Geom::Transformation.scaling(ORIGIN, 1, 1, 1)).to_a
    tr[12] = origin.x
    tr[13] = origin.y
    tr[14] = origin.z
    return Geom::Transformation.new(tr)
  end


  def self.heightmap_to_mesh
    temp_path = File.expand_path(TT::System.temp_path)
    temp_file = File.join(temp_path, 'TT_BMP2Mesh.bmp')
    model = Sketchup.active_model
    image = model.selection[0]
    tw = Sketchup.create_texture_writer
    tw.load(image)
    tw.write(image, temp_file)
    dib = GL_BMP.new(temp_file)
    File.delete(temp_file)
    Sketchup.active_model.tools.push_tool(PlaceMeshTool.new(dib, image))
  end


  def self.bitmap_to_mesh_tool
    # Select file
    filename = UI.openpanel('Select BMP File', nil, '*.bmp')
    return if filename.nil?
    # Load data
    dib = GL_BMP.new(filename)
    # Make the user pick the position of the mesh.
    Sketchup.active_model.tools.push_tool(PlaceMeshTool.new(dib))
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------

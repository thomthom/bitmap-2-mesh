#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'testup/testcase'


module TT::Plugins::BitmapToMesh
module Tests
class TC_HeightMap < TestUp::TestCase

  def setup
    start_with_empty_model
  end

  def teardown
    # ...
  end


  # Creates a grey scale image.
  def create_test_image_rep(width, height, data)
    assert_equal(width * height, data.size)
    image_rep = Sketchup::ImageRep.new
    image_rep.set_data(width, height, 8, 0, data.pack("C*"))
    image_rep
  end

  # @param [Sketchup::Model] model
  # @param [Sketchup::ImageRep] image_rep
  def create_test_material(model, image_rep)
    material = model.materials.add('TestUp')
    material.texture = image_rep
    material
  end


  def test_generate_solid
    model = Sketchup.active_model
    data = [64, 128, 192, 255]
    image_rep = create_test_image_rep(2, 2, data)
    bitmap = Bitmap.new(image_rep)
    material = create_test_material(model, image_rep)
    tr = Geom::Transformation.scaling(10, 20, 30)
    heightmap = HeightmapMesh.new
    group = heightmap.generate(model.entities, bitmap, material, tr, solid: true)
    assert_kind_of(Sketchup::Group, group)
  end

  def test_generate_solid_border_at_ground
    model = Sketchup.active_model
    data = [0, 64, 128, 255]
    image_rep = create_test_image_rep(2, 2, data)
    bitmap = Bitmap.new(image_rep)
    material = create_test_material(model, image_rep)
    tr = Geom::Transformation.scaling(10, 20, 30)
    heightmap = HeightmapMesh.new
    group = heightmap.generate(model.entities, bitmap, material, tr, solid: true)
    assert_kind_of(Sketchup::Group, group)
  end

end # class
end # module
end # module
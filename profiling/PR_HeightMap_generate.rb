require "speedup.rb"
require 'testup/testcase'
# require_relative '../tests/lib/test_utilities.rb'


module TT::Plugins::VertexTools2
module Profiling

  class PR_Selection_SoftSelection < SpeedUp::ProfileTest

    include TestUp::SketchUpTestUtilities
    include Tests::TestUtilities


    def setup_testcase
      # open_model('models/image-128x128.skp')
      model = start_with_empty_model
      model = Sketchup.active_model
      @entities = model.active_entities

      image_file = project_file('resources/dem02_original_100.bmp')
      @image = @entities.add_image(image_file, ORIGIN, 1.m)
      # @image = @entities.grep(Sketchup::Image).first

      @bitmap = Bitmap.from_image(@image)
      @material = Image.clone_material(@image)
    end

    def teardown_testcase
      # ...
    end

    def setup
      # Clean up any groups previously generated by Heightmap#generate.
      groups = @entities.grep(Sketchup::Group)
      @entities.erase_entities(groups)
    end


    def profile_generate
      @heightmap.generate(@entities, @bitmap, @material)
    end

  end # class

end # module
end # module
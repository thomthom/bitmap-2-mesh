require "speedup.rb"
require 'testup/testcase'
require_relative '../tests/lib/test_utilities.rb'

module TT::Plugins::BitmapToMesh
module Profiling

  class PR_ImageToMesh < SpeedUp::ProfileTest

    include TestUp::SketchUpTestUtilities
    include Tests::TestUtilities


    def setup_testcase
      # open_model('models/image-128x128.skp')
      model = start_with_empty_model
      model = Sketchup.active_model
      @entities = model.active_entities

      image_file = project_file('resources/heightmaps/dem02_original_100.bmp')
      @image = @entities.add_image(image_file, ORIGIN, 1.m)

      @bitmap = Bitmap.from_image(@image)
      @material = Image.clone_material(@image)
    end

    def teardown_testcase
      # ...
    end

    def setup
      # Clean up any groups previously generated.
      groups = @entities.grep(Sketchup::Group)
      @entities.erase_entities(groups)
    end


    def profile_generate_via_entities
      TT::Plugins::BitmapToMesh.image_to_mesh(@image, use_builder: false)
    end

    def profile_generate_via_entities_builder
      TT::Plugins::BitmapToMesh.image_to_mesh(@image, use_builder: true)
    end

  end # class

end # module
end # module

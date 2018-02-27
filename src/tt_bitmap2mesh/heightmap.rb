#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

module TT::Plugins::BitmapToMesh
  class HeightmapMesh

    attr_accessor :out

    def initialize
      @stdout = $stdout
    end

    # Duplicate of Geom::PolygonMesh constants:
    # http://ruby.sketchup.com/Geom/PolygonMesh.html#constant_summary
    # The constants were added in SU2014. When the extension drop support for
    # older SketchUp versions the magic numbers can be replaced with the new
    # constants.
    AUTO_SOFTEN = 4 # Geom::PolygonMesh::AUTO_SOFTEN
    SMOOTH_SOFT_EDGES = 8 # Geom::PolygonMesh::SMOOTH_SOFT_EDGES

    SMOOTH_AND_SOFTEN = AUTO_SOFTEN | SMOOTH_SOFT_EDGES


    def generate(entities, bitmap, material = nil, transformation = IDENTITY)
      model = entities.model

      bitmap_width = bitmap.width # Cache - avoid repeated method call.
      bitmap_height = bitmap.height # Cache - avoid repeated method call.

      # Given a 100x100 pixel image 99x99 quads will be produced, twice as many
      # triangles.
      num_polygons = (bitmap_width - 1) * (bitmap_height - 1) * 2
      num_points = bitmap_width * bitmap_height

      log "Bitmap To Mesh: (#{bitmap.provider})"
      log "> Pixels: #{num_points} (#{bitmap_width}x#{bitmap_height})"
      log "> Vertices: #{num_points}"
      log "> Triangles: #{num_polygons}"
      start_time = Time.now

      # Read colour values and generate 3D points.
      points = []
      bitmap_height.times { |y|
        bitmap_width.times { |x|
          index = (bitmap_width * y) + x
          color = bitmap.data[index]
          # Generate a Point3d from pixel colour.
          z = color.luminance / 255.0
          points << Geom::Point3d.new(x, y, z)
        }
      }
      total = points.size.to_f
      log "> Processing data took: #{Time.now - start_time}s"

      t = Time.now
      # (!) Bottleneck!
      # Populate the mesh with the points and get a set of vertex indicies.
      w = bitmap.width
      h = bitmap.height
      u_step = 1.0 / bitmap.width.to_f
      v_step = 1.0 / bitmap.height.to_f
      # (!) Progressbar and Sketchup.status_bar impact performance.
      mesh = Geom::PolygonMesh.new(num_points, num_polygons)
      uv_map = material && mesh.respond_to?(:set_uv)
      mesh_indicies = []
      points.each_with_index { |point, i|
        # Sketchup.status_text = sprintf("Indexing points: %.1f%%", (i / total) * 100.0)
        mesh_indicies << mesh.add_point(point)

        next unless uv_map
        y = i / h
        x = i - (h * y)
        u = x * u_step
        v = y * v_step
        mesh.set_uv(i + 1, [u, v, 0], true)
      }
      log "> Indexing points took: #{Time.now - start_time}s"

      t = Time.now
      # Generate the mesh
      columns = bitmap.width - 1
      rows = bitmap.height - 1
      rows.times { |y|
        columns.times { |x|
          r = y * bitmap_width # Current row
          # Sketchup.status_text = sprintf("Generating mesh: %.1f%%", ((x+r) / total) * 100.0)
          # Collect the indicies from the pixel we're interested in.
          point_indicies = [ x+r, x+1+r, x+bitmap_width+1+r, x+bitmap_width+r ]
          # Get the point indicies and mirror orientation
          indicies = point_indicies.map { |i| mesh_indicies[i] }
          next unless indicies.length > 2
          mesh.add_polygon(indicies[0], indicies[1], indicies[2])
          mesh.add_polygon(indicies[0], indicies[2], indicies[3])
        }
      }
      log "> Generating mesh took: #{Time.now - t}s"

      t = Time.now
      Sketchup.status_text = 'Filling group with mesh...'
      # Add the geometry to the model
      group = entities.add_group
      group.transformation = transformation
      group.entities.fill_from_mesh(mesh, true, SMOOTH_AND_SOFTEN, material)
      log "> Filling mesh took: #{Time.now - t}s"
      log "Total time: #{Time.now - start_time}s"
      group
    end

    private

    def log(*args)
      @stdout.send(:puts, *args)
    end

  end # class
end # module

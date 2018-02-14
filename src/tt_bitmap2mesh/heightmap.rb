#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/image/bmp'


module TT::Plugins::BitmapToMesh
  class HeightmapMesh

    def generate(entities, bitmap, width, height, depth, material)
      model = entities.model

      step_x = width  / bitmap.width
      step_y = height / bitmap.height
      step_z = depth  / 255

      puts "Bitmap To Mesh: (#{bitmap.provider})"
      puts "> Pixels: #{bitmap.width * bitmap.height} (#{bitmap.width}x#{bitmap.height})"
      puts "> Triangles: #{bitmap.width * bitmap.height * 2}"
      start_time = Time.now

      # Read colour values and generate 3D points.
      # TODO: Reuse logic in BitmapRender. It dupliates the greyscale logic.
      #       Additionally the down-sampling logic can be used, but need UI
      #       allow the user to control max-sample size.
      points = []
      w = bitmap.width
      h = bitmap.height
      u_step = 1.0 / bitmap.width.to_f
      v_step = 1.0 / bitmap.height.to_f
      # progress = TT::Progressbar.new(bitmap.pixels, 'Reading Image')
      bitmap.height.times { |y|
        bitmap.width.times { |x|
          # progress.next
          index = (bitmap.width * y) + x
          color = bitmap.data[index]
          # Generate a Point3d from pixel colour.
          point_x = step_x * x
          point_y = step_y * y
          point_z = step_z * color.luminance
          points << Geom::Point3d.new(point_x, point_y, point_z)
        }
      }
      total = points.size.to_f
      puts "> Processing data took: #{Time.now - start_time}s"

      t = Time.now
      # (!) Bottleneck!
      # Populate the mesh with the point and build an vertex index.
      # progress = TT::Progressbar.new(points, 'Indexing Points')
      mesh = Geom::PolygonMesh.new(points.size, points.size * 2)
      mesh_indicies = []
      points.each_with_index { |point, i|
        # progress.next
        # Sketchup.status_text = sprintf("Indexing points: %.1f%%", (i / total) * 100.0)
        mesh_indicies << mesh.add_point(point)

        y = i / h
        x = i - (h * y)
        u = x * u_step
        v = y * v_step
        mesh.set_uv(i + 1, [u, v, 0], true)
      }
      puts "> Indexing points took: #{Time.now - start_time}s"

      # Compute UV mapping:
      #   t = Time.now
      #   w = bitmap.width
      #   h = bitmap.height
      #   u_step = 1.0 / bitmap.width.to_f
      #   v_step = 1.0 / bitmap.height.to_f
      #   # progress = TT::Progressbar.new(points, 'Adding UV mapping')
      #   points.each_with_index { |pt, i|
      #     # progress.next
      #     # Sketchup.status_text = sprintf("UV Mapping: %.1f%%", (i / total) * 100.0)
      #     y = i / h
      #     x = i - (h * y)
      #     u = x * u_step
      #     v = y * v_step
      #     uv = Geom::Point3d.new(u, v, 0)
      #     mesh.set_uv(i + 1, uv, true)
      #   }
      #   puts "> UV mapping took: #{Time.now - t}s"
      # end

      t = Time.now
      # Generate the mesh
      # progress = TT::Progressbar.new(bitmap.pixels, 'Generating Mesh')
      0.upto(bitmap.height-2) { |y|
        0.upto(bitmap.width-2) { |x|
          # progress.next
          r = y * bitmap.width # Current row
          # Sketchup.status_text = sprintf("Generating mesh: %.1f%%", ((x+r) / total) * 100.0)
          # Pick out the indicies from the patch 2D-matrix we're interested in.
          point_indicies = [ x+r, x+1+r, x+bitmap.width+1+r, x+bitmap.width+r ]
          # Get the point indicies and mirror orientation
          indicies = point_indicies.map { |i| mesh_indicies[i] }
          next unless indicies.length > 2
          mesh.add_polygon(indicies[0], indicies[1], indicies[2])
          mesh.add_polygon(indicies[0], indicies[2], indicies[3])
        }
      }
      puts "> Generating mesh took: #{Time.now - t}s"

      t = Time.now
      Sketchup.status_text = 'Filling group with mesh...'
      # Add the geometry to the model
      group = entities.add_group
      flags = 4 | 8 # AUTO_SOFTEN | SMOOTH_SOFT_EDGES
      if mesh.respond_to?(:set_uv)
        # material = get_material(@image, @bitmap)
        group.entities.fill_from_mesh(mesh, true, flags, material)
      else
        group.entities.fill_from_mesh(mesh, true, flags)
      end
      puts "> Filling mesh took: #{Time.now - t}s"
      puts "Total time: #{Time.now - start_time}s"
      group
    end

  end # class
end # module

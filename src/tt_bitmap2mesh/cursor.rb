#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'TT_Lib2/core.rb'

module TT::Plugins::BitmapToMesh
  module Cursor

    # Definitions of cursor resources.
    # :symbol_id => ['filename.png', x, y]
    @cursors = {
      :default            => 0,
      :invalid            => 663,
      :hand               => 671,
      :hand_invalid       => 918,
      :link               => 670,
      :erase              => 645,
      :pencil             => 632,
      :freehand           => 655,
      :arc_1              => 629,
      :arc_2              => 631,
      :arc_3              => 630,
      :man                => 612,
      :position_camera    => 653,
      :position_camera_3d => 902,
      :walk               => 420,
      :walk_3d            => 904,
      :look_around        => 418,
      :look_around_3d     => 903,
      :orbit              => 419,
      :orbit_3d           => 900,
      :pan                => 1003,
      :pan_2d             => 901,
      :zoom               => 421,
      :zoom_region        => 422,
      :zoom_3d            => 905,
      :zoom_2d            => 907,
      :zoom_2d_region     => 906,
      :offset             => 646,
      :offset_invalid     => 679,
      :dropper            => 651,
      :dropper_texture    => 652,
      :paint              => 681, # 647
      :paint_same         => 650,
      :paint_object       => 649,
      :paint_connected    => 648,
      :paint_invalid      => 680,
      :text               => 678,
      :follow_me          => 640,
      :follow_me_invalid  => 678,
      :pushpull           => 639,
      :pushpull_add       => 755,
      :pushpull_invalid   => 707,
      :tape               => 638,
      :tape_add           => 731,
      :select             => 633,
      :select_add         => 634,
      :select_remove      => 636,
      :select_toggle      => 635,
      :select_step_1      => 924,
      :select_step_2      => 925,
      :select_invalid     => 926,
      :rectangle          => 637,
      :move               => 641,
      :move_copy          => 642,
      :move_fold          => 672,
      :move_invalid       => 673,
      :position           => 658,
      :position_invalid   => 673,
      :scale              => 736,
      :scale_invalid      => 730,
      :scale_n_s          => 659,
      :scale_n_ne         => 666,
      :scale_ne           => 661,
      :scale_ne_e         => 667,
      :scale_w_e          => 660,
      :scale_n_nw         => 665,
      :scale_nw           => 662,
      :scale_nw_w         => 664,
      :rotate             => 643,
      :rotate_copy        => 644,
      :rotate_invalid     => 713
    }

    # @param [Symbol] id
    # @return [Integer, nil]
    def self.get_id(id)
      return nil unless @cursors.key?(id)
      # Load cursors on demand
      if @cursors[id].is_a?(Array)
        cursor_file, x, y = @cursors[id]
        filename = File.join( TT::Cursor::PATH, cursor_file )
        @cursors[id] = UI.create_cursor( filename, x, y )
      end
      return @cursors[id]
    end

    # @param [Geom::Vector3d] screen_vector
    # @param [Sketchup::View] view
    # @return [Integer, nil]
    def self.get_vector2d_cursor(screen_vector, view)
      cursors = self.scale_handles
      cursor_id = nil
      nearest_angle = nil
      for vector, cursor in cursors
        a1 = vector.angle_between(screen_vector).abs
        a2 = vector.angle_between(screen_vector.reverse).abs
        angle = [a1, a2].min
        if nearest_angle.nil? || angle < nearest_angle
          nearest_angle = angle
          cursor_id = cursor
        end
      end
      cursor_id
    end

    # @param [Geom::Vector3d] vector
    # @param [Sketchup::View] view
    # @return [Integer, nil]
    def self.get_vector3d_cursor(vector, view)
      pt1 = ORIGIN
      pt2 = ORIGIN.offset(vector)
      spt1 = view.screen_coords(pt1)
      spt2 = view.screen_coords(pt2)
      spt1.z = 0
      spt2.z = 0
      screen_vector = spt1.vector_to(spt2)
      self.get_vector2d_cursor(screen_vector, view)
    end

    # @return [Hash]
    def self.scale_handles
      @scale_handles ||= self.compute_scale_handles
      @scale_handles
    end

    # @return [Hash]
    def self.compute_scale_handles
      cursor_ids = [
        self.get_id(:scale_nw_w),
        self.get_id(:scale_nw),
        self.get_id(:scale_n_nw),
        self.get_id(:scale_n_s),
        self.get_id(:scale_n_ne),
        self.get_id(:scale_ne),
        self.get_id(:scale_ne_e),
        self.get_id(:scale_w_e)
      ].reverse
      cursors = {}
      angle = (180.0 / cursor_ids.size).degrees
      cursor_ids.each_with_index { |id, index|
        tr = Geom::Transformation.rotation(ORIGIN, Z_AXIS, -angle * index)
        vector = X_AXIS.transform(tr)
        cursors[vector] = id
      }
      cursors
    end

  end # module
end # module

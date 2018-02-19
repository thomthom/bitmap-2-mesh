#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'tt_bitmap2mesh/text'


module TT::Plugins::BitmapToMesh
  class Leader

    attr_accessor :text, :position

    def initialize(text)
      @text = Text.new(text)
      @text.align = TextAlignCenter
      @position = ORIGIN.clone
    end

    def position
      @position
    end

    def position=(value)
      @position = value
    end

    def draw(view)
      @text.position = view.screen_coords(@position)
      @text.draw(view)
    end

    private

  end # class
end # module

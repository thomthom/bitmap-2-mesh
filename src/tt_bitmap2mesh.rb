#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
require 'extensions.rb'

module TT
module Plugins
module BitmapToMesh

  file = __FILE__.dup
  # Account for Ruby encoding bug under Windows.
  file.force_encoding('UTF-8') if file.respond_to?(:force_encoding)
  # Support folder should be named the same as the root .rb file.
  folder_name = File.basename(file, '.*')

  # Plugin information
  PLUGIN_ID       = File.basename(__FILE__).freeze
  PLUGIN_NAME     = 'Bitmap to Mesh'.freeze
  PLUGIN_VERSION  = '0.6.0'.freeze

  # Resource paths
  PATH_ROOT     = File.dirname(file).freeze
  PATH          = File.join(PATH_ROOT, folder_name).freeze


  unless file_loaded?(__FILE__)
    loader = File.join(PATH, 'core')
    ex = SketchupExtension.new(PLUGIN_NAME, loader)
    ex.description = 'Generates 2D and 3D mesh from bitmaps.'
    ex.version     = PLUGIN_VERSION
    ex.copyright   = 'Thomas Thomassen © 2010-2018'
    ex.creator     = 'Thomas Thomassen (thomas@thomthom.net)'
    Sketchup.register_extension(ex, true)
  end

end # module BitmapToMesh
end # module Plugins
end # module TT

file_loaded(__FILE__)

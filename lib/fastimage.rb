# frozen_string_literal: true
# coding: ASCII-8BIT

# FastImage finds the size or type of an image given its uri.
# It is careful to only fetch and parse as much of the image as is needed to determine the result.
# It does this by using a feature of Net::HTTP that yields strings from the resource being fetched
# as soon as the packets arrive.
#
# No external libraries such as ImageMagick are used here, this is a very lightweight solution to
# finding image information.
#
# FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD, SVG and WEBP files.
#
# FastImage can also read files from the local filesystem by supplying the path instead of a uri.
# In this case FastImage reads the file in chunks of 256 bytes until
# it has enough. This is possibly a useful bandwidth-saving feature if the file is on a network
# attached disk rather than truly local.
#
# FastImage will automatically read from any object that responds to :read - for
# instance an IO object if that is passed instead of a URI.
#
# FastImage will follow up to 4 HTTP redirects to get the image.
#
# FastImage also provides a reader for the content length header provided in HTTP.
# This may be useful to assess the file size of an image, but do not rely on it exclusively -
# it will not be present in chunked responses for instance.
#
# FastImage accepts additional HTTP headers. This can be used to set a user agent
# or referrer which some servers require. Pass an :http_header argument to specify headers,
# e.g., :http_header => {'User-Agent' => 'Fake Browser'}.
#
# FastImage can give you information about the parsed display orientation of an image with Exif
# data (jpeg or tiff).
#
# === Examples
#   require 'fastimage'
#
#   FastImage.size("http://stephensykes.com/images/ss.com_x.gif")
#   => [266, 56]
#   FastImage.type("http://stephensykes.com/images/pngimage")
#   => :png
#   FastImage.type("/some/local/file.gif")
#   => :gif
#   File.open("/some/local/file.gif", "r") {|io| FastImage.type(io)}
#   => :gif
#   FastImage.new("http://stephensykes.com/images/pngimage").content_length
#   => 432
#   FastImage.new("http://stephensykes.com/images/ExifOrientation3.jpg").orientation
#   => 3
#
# === References
# * http://www.anttikupila.com/flash/getting-jpg-dimensions-with-as3-without-loading-the-entire-file/
# * http://pennysmalls.wordpress.com/2008/08/19/find-jpeg-dimensions-fast-in-pure-ruby-no-ima/
# * https://rubygems.org/gems/imagesize
# * https://github.com/remvee/exifr
#

require 'net/https'
require 'delegate'
require 'pathname'
require 'zlib'
require 'base64'
require 'uri'

require 'fastimage/fastimage_parsing/stream_util'
require 'fastimage/fastimage_parsing/fiber_stream'
require 'fastimage/fastimage_parsing/type_parser'

require 'fastimage/fastimage_parsing/image_base'
require 'fastimage/fastimage_parsing/bmp'
require 'fastimage/fastimage_parsing/gif'
require 'fastimage/fastimage_parsing/jpeg'
require 'fastimage/fastimage_parsing/exif'
require 'fastimage/fastimage_parsing/svg'
require 'fastimage/fastimage_parsing/heic'
require 'fastimage/fastimage_parsing/tiff'
require 'fastimage/fastimage_parsing/png'
require 'fastimage/fastimage_parsing/webp'
require 'fastimage/fastimage_parsing/psd'
require 'fastimage/fastimage_parsing/ico'

require 'fastimage/fastimage'

# see http://stackoverflow.com/questions/5208851/i/41048816#41048816
if RUBY_VERSION < "2.2"
  module URI
    DEFAULT_PARSER = Parser.new(:HOSTNAME => "(?:(?:[a-zA-Z\\d](?:[-\\_a-zA-Z\\d]*[a-zA-Z\\d])?)\\.)*(?:[a-zA-Z](?:[-\\_a-zA-Z\\d]*[a-zA-Z\\d])?)\\.?")
  end
end

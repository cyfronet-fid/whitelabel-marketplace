# frozen_string_literal: true

require "mini_magick"

desc "Add an extension to the images that has lack of them"
task :add_extension_to_images, [:root_url] => :environment do |_, args|
  routes_default_host = Rails.application.routes.default_url_options[:host]
  app_default_host = Mp::Application.default_url_options[:host]

  Rails.application.routes.default_url_options[:host] = args.root_url
  Mp::Application.default_url_options[:host] = args.root_url

  include Rails.application.routes.url_helpers
  include ApplicationHelper

  add_extension_to_images
ensure
  Rails.application.routes.default_url_options[:host] = routes_default_host
  Mp::Application.default_url_options[:host] = app_default_host
end

class LogoNotAvailableError < StandardError
  def initialize(msg)
    super(msg)
  end
end

def add_extension_to_images
  objects_with_img = Provider.all.to_a
                             .push(*Service.all.to_a)
                             .push(*Category.all.to_a)
                             .push(*ScientificDomain.all.to_a)
  objects_with_img.each do |object|
    if should_rename(object.logo)
      filename = object.pid.blank? ? "logo_" + to_slug(object.name) : object.pid
      rename_img(object.logo, filename)
    end
  end
end

def rename_img(attachment, filename)
  logo = open(url_for(attachment), ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE)
  logo_content_type = logo.content_type
  extension = Rack::Mime::MIME_TYPES.invert[logo_content_type]

  unless [".jpg", ".jpeg", ".pjpeg", ".png", ".gif", ".tiff"].include?(extension)
    img = MiniMagick::Image.read(logo, extension)
    img.format "png" do |convert|
      convert.args.unshift "800x800"
      convert.args.unshift "-resize"
      convert.args.unshift "1200"
      convert.args.unshift "-density"
      convert.args.unshift "none"
      convert.args.unshift "-background"
    end
    logo = StringIO.new
    logo.write(img.to_blob)
    logo.seek(0)
    logo_content_type = "image/png"
  end
  if !logo.blank? && logo_content_type.start_with?("image")
    attachment.attach(io: logo, filename: filename + extension, content_type: logo_content_type)
  end
rescue OpenURI::HTTPError, Errno::EHOSTUNREACH, LogoNotAvailableError, SocketError => e
  Rails.logger.warn "ERROR - there was a problem processing image for #{filename} #{url_for(attachment)}: #{e}"
rescue => e
  Rails.logger
       .warn "ERROR - there was a unexpected problem processing image for #{filename} #{url_for(attachment)}: #{e}"
end

def should_rename(attachment)
  if attachment.blank? || attachment.filename.blank?
    return false
  end

  has_ext = attachment.filename.to_s
                          .match(/\.(jpg|jpeg|pjpeg|png|gif|tiff")$/)
  attachment.attached? && !has_ext
end

def to_slug(ret)
  ret.downcase!
  ret.strip!
  ret.gsub!(/['`]/, "")
  ret.gsub!(/\s*@\s*/, " at ")
  ret.gsub!(/\s*&\s*/, " and ")
  ret.gsub!(/\s*[^A-Za-z0-9.-]\s*/, "-")
  ret.gsub!(/_+/, "_")
  ret.gsub!(/\A[_.]+|[_.]+\z/, "")
  ret.gsub!(/-+/, "-")
  ret.gsub!(/-$/, "")
  ret
end

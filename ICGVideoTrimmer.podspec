# coding: utf-8
Pod::Spec.new do |s|

  s.name         = "ICGVideoTrimmer"
  s.version      = "2.2.2"
  s.summary      = "A library for quick video trimming."

  s.description  = <<-DESC
                   ICGVideoTrimmer provides an easy-to-use tool for trimming videos in iOS apps. It was built to mimic the look and behavior of Instagram’s video trimmer.
                   DESC

  s.homepage     = "https://github.com/itsmeichigo/ICGVideoTrimmer"
  s.screenshots  = "https://raw.githubusercontent.com/itsmeichigo/ICGVideoTrimmer/master/trimmer.gif"


  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Huong Do" => "huongdt29@gmail.com" }
  s.social_media_url   = "http://twitter.com/itsmeichigo"

  s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/jrtaal/ICGVideoTrimmer.git", :tag => s.version.to_s }

  s.source_files  = "Source"

  s.framework  = "UIKit", "MobileCoreServices", "AVFoundation"

  s.requires_arc = true

end

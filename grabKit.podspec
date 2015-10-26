Pod::Spec.new do |s|
  s.name         = "grabKit"
  s.version      = "1.4.3"
  s.summary      = "Drop-in iOS component to easily import photos from Facebook, FlickR, Instagram, Picasa, and more."
  s.description  = <<-DESC
				GrabKit allows you to retrieve photos from  :
					* Facebook
					* FlickR
					* Picasa
					* Instagram
					* iPhone/iPad
					* ... and more to come.
					DESC
  s.homepage     = "https://github.com/pierrotsmnrd/grabKit"
  s.screenshots  = "https://github.com/pierrotsmnrd/grabKit/blob/master/doc/demo.gif"

  s.license      = { :type => 'MIT', :file => 'LICENSE.txt' }

  s.author       = { "Pierre-Olivier Simonard" => "pierre.olivier.simonard@gmail.com" }
  
  s.source       = { :git => "https://github.com/PeterWong2015/grabKit.git", :tag => 'v1.4.3' }

  s.requires_arc = true
  
  s.source_files = 'grabKit/grabKit/**/*.{h,m}'
  
  s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }
  
  s.ios.resource_bundle = { 'GrabKitBundle' => ['grabKit/grabKit/GrabKitPicker/Resources/*', 'grabKit/grabKit/**/*.{xib}']}

  s.dependency 'FBSDKCoreKit'
  s.dependency 'ISO8601DateFormatter'
  s.dependency 'MBProgressHUD'
  s.dependency 'objectiveflickr'
  s.dependency 'AFNetworking'

  s.ios.frameworks = 'Accounts',  'AssetsLibrary', 'CFNetwork', 'QuartzCore', 'Security', 'Social', 'SystemConfiguration'

end
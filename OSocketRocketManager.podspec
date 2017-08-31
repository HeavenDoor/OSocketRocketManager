Pod::Spec.new do |s|

  s.name                 = "OSocketRocketManager"
  s.version              = "1.0.1"
  s.summary              = "SocketRocket二次封装"
  s.description          = <<-DESC
                           SocketRocket二次封装 1.0.1版本
                           DESC
  s.homepage             = "https://github.com/Leuangwn/OSocketRocketManager"
  s.license              = { :type => "MIT", :file => "LICENSE" }
  s.author               = { "Leuang" => "2042805653@qq.com" }
  s.platform             = :ios, "8.0"
  s.source               = { :git => "https://github.com/Leuangwn/OSocketRocketManager.git", :tag => s.version }
  s.source_files         = "OSocketRocketManager/*.{h,m}"
  s.dependency           "SocketRocket"
  s.requires_arc         = true

end


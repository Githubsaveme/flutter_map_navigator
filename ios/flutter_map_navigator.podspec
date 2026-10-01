Pod::Spec.new do |s|
  s.name             = 'flutter_map_navigator'
  s.version          = '0.0.1'
  s.summary          = 'Production-grade Flutter Navigation SDK Plugin'
  s.description      = 'Core location, background tracking, and navigation functionality for iOS.'
  s.homepage         = 'https://github.com/example/flutter_map_navigator'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Flutter Map Navigator Team' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

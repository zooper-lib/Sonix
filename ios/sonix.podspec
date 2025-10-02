Pod::Spec.new do |s|
  s.name             = 'sonix'
  s.version          = '0.0.1'
  s.summary          = 'Flutter audio waveform package'
  s.description      = 'Flutter audio waveform package with FFMPEG support'
  s.homepage         = 'https://github.com/your-repo/sonix'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Bundle the sonix_native library
  s.vendored_libraries = 'libsonix_native.a'
end
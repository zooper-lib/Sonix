Pod::Spec.new do |spec|
  spec.name          = 'sonix_native'
  spec.version       = '1.0.0'
  spec.license       = { :type => 'MIT' }
  spec.homepage      = 'https://github.com/your-org/sonix'
  spec.authors       = { 'Sonix Team' => 'team@sonix.dev' }
  spec.summary       = 'Native audio decoding library for Sonix Flutter package'
  spec.source        = { :path => '.' }
  spec.source_files  = '../src/**/*.{h,c}'
  spec.public_header_files = '../src/sonix_native.h'
  
  spec.ios.deployment_target = '11.0'
  spec.osx.deployment_target = '10.13'
  
  # Compiler settings
  spec.compiler_flags = '-O3', '-ffast-math'
  spec.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64 arm64',
    'VALID_ARCHS[sdk=iphoneos*]' => 'arm64',
    'OTHER_CFLAGS' => '-DIOS'
  }
  
  # Header search paths
  spec.header_mappings_dir = '../src'
  
  # Framework dependencies
  spec.frameworks = 'Foundation'
end
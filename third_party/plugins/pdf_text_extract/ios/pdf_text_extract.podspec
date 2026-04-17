Pod::Spec.new do |s|
  s.name             = 'pdf_text_extract'
  s.version          = '0.0.1'
  s.summary          = 'Extract text content from PDF documents in Flutter.'
  s.description      = <<-DESC
Extract text content from PDF documents in Flutter.
                       DESC
  s.homepage         = 'https://github.com/AlessioLuciani/flutter-pdf-text/tree/master'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Contributors' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '11.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64'
  }
  s.swift_version = '5.0'
end

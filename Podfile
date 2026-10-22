workspace 'Pyto'

project 'Pyto'

# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'Pyto' do

  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Pyto

  inhibit_all_warnings!

  pod 'SplitKit', :git => 'https://github.com/ColdGrub1384/SplitKit.git', :commit => 'd47136150c5a5c16dc357f4ad24625925684216e'
  pod 'SourceEditor', :git => 'https://github.com/ColdGrub1384/source-editor.git', :commit => '66812125b988d6593d601df53e472073776e7809'
  pod 'Zip'
  pod 'Down', :git => 'https://github.com/ColdGrub1384/Down.git'
  pod 'FileBrowser', :git => 'https://github.com/ColdGrub1384/FileBrowser.git'
  pod 'MultiPeer'
  pod 'SwiftyStoreKit'
  pod 'ObjectUserDefaults'
  pod 'TrueTime'
  pod 'Highlightr', :git => 'https://github.com/brunophilipe/Highlightr.git'
  pod "GCDWebServer", "~> 3.0"
  pod 'freetype2'
  pod 'SwiftSoup'
end

target 'SwiftUI Preview' do

use_frameworks!
  inhibit_all_warnings!

  pod 'Highlightr', :git => 'https://github.com/brunophilipe/Highlightr.git'

  end

  target 'WidgetExtension' do

  use_frameworks!
  inhibit_all_warnings!

  pod 'freetype2'

end

target 'Pyto Screenshots' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Pyto

  inhibit_all_warnings!

  pod 'SplitKit', :git => 'https://github.com/ColdGrub1384/SplitKit.git', :commit => 'd47136150c5a5c16dc357f4ad24625925684216e'
  pod 'SourceEditor', :git => 'https://github.com/ColdGrub1384/source-editor.git', :commit => '66812125b988d6593d601df53e472073776e7809'
  pod 'Zip'
  pod 'Down', :git => 'https://github.com/ColdGrub1384/Down.git'
  pod 'FileBrowser', :git => 'https://github.com/ColdGrub1384/FileBrowser.git'
  pod 'MultiPeer'
  pod 'SwiftyStoreKit'
  pod 'ObjectUserDefaults'
  pod 'TrueTime'
  pod 'Highlightr', :git => 'https://github.com/brunophilipe/Highlightr.git'
  pod 'freetype2'
  pod 'SwiftSoup'
end

# post install
post_install do |installer|
    # Keep the pinned SplitKit behavior, including pointer interactions. Expose
    # only the two real layout constraints that Pyto's console/editor controls.
    split_sources = Dir.glob(File.join(__dir__, 'Pods', 'SplitKit', '**', '*.swift'))
    %w[firstViewHeightConstraint firstViewHeightRatioConstraint].each do |name|
        declaration = /\bprivate(\s+var\s+#{Regexp.escape(name)}\b)/
        split_sources.each do |path|
            original = File.read(path)
            updated = original.gsub(declaration, 'public\1')
            next if updated == original
            File.chmod(File.stat(path).mode | 0200, path)
            File.write(path, updated)
        end
        exposed = split_sources.any? { |path| File.read(path).match?(/\bpublic\s+var\s+#{Regexp.escape(name)}\b/) }
        raise "SplitKit API compatibility patch failed: #{name}" unless exposed
    end
    # Build settings
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings = config.build_settings.dup
            if config.build_settings['PRODUCT_MODULE_NAME'] == 'SavannaKit' || config.build_settings['PRODUCT_MODULE_NAME'] == 'SourceEditor' || config.build_settings['PRODUCT_MODULE_NAME'] == 'SplitKit'
                puts "Set Swift version"
                config.build_settings['SWIFT_VERSION'] = '4.0'
            end
            config.build_settings["IPHONEOS_DEPLOYMENT_TARGET"] = "11.0"
        end
    end
end

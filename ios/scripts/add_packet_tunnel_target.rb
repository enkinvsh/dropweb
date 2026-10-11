# One-off: adds the PacketTunnel app-extension target to Runner.xcodeproj.
# Run from repo root (xcodeproj gem ships with CocoaPods):
#   GEM_HOME=$(brew --prefix cocoapods)/libexec $(brew --prefix ruby)/bin/ruby ios/scripts/add_packet_tunnel_target.rb
require 'xcodeproj'

project = Xcodeproj::Project.open(File.expand_path('../Runner.xcodeproj', __dir__))
abort 'PacketTunnel target already exists' if project.targets.any? { |t| t.name == 'PacketTunnel' }
runner = project.targets.find { |t| t.name == 'Runner' }

ext = project.new_target(:app_extension, 'PacketTunnel', :ios, '13.0')
group = project.main_group.new_group('PacketTunnel', 'PacketTunnel')
ext.add_file_references([group.new_reference('PacketTunnelProvider.swift')])
%w[Info.plist PacketTunnel.entitlements PacketTunnel-Bridging-Header.h].each { |f| group.new_reference(f) }
xcconfig = group.new_reference('PacketTunnel.xcconfig')
ext.add_system_framework('NetworkExtension')

core = '$(PROJECT_DIR)/../libclash/ios'
ext.build_configurations.each do |config|
  config.base_configuration_reference = xcconfig
  s = config.build_settings
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'app.dropweb.PacketTunnel'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks',
                                  '@executable_path/../../Frameworks']
  s['INFOPLIST_FILE'] = 'PacketTunnel/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'PacketTunnel/PacketTunnel.entitlements'
  s['SWIFT_OBJC_BRIDGING_HEADER'] = 'PacketTunnel/PacketTunnel-Bridging-Header.h'
  s['HEADER_SEARCH_PATHS'] = core
  s['OTHER_LDFLAGS'] = ['-force_load', "#{core}/libclash.a",
                        '-framework', 'Security', '-framework', 'CoreFoundation', '-lresolv']
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['SKIP_INSTALL'] = 'YES'
end

runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end
runner.add_dependency(ext)
embed = runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
embed.add_file_reference(ext.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# Must run before Flutter's "Thin Binary" script, else Xcode reports "Cycle inside Runner".
runner.build_phases.delete(embed)
frameworks = runner.build_phases.find { |b| b.display_name == 'Embed Frameworks' }
runner.build_phases.insert(runner.build_phases.index(frameworks) + 1, embed)
project.save

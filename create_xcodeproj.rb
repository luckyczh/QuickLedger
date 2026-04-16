require "xcodeproj"

project_path = File.join(__dir__, "QuickLedger.xcodeproj")
project = Xcodeproj::Project.new(project_path)

main_group = project.main_group
app_group = main_group.new_group("QuickLedger", "QuickLedger")

target = project.new_target(:application, "QuickLedger", :ios, "17.0")
target.deployment_target = "17.0"

configurations = target.build_configurations
configurations.each do |config|
  config.build_settings["SWIFT_VERSION"] = "5.0"
  config.build_settings["PRODUCT_NAME"] = "$(TARGET_NAME)"
  config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.yinchen.quickledger"
  config.build_settings["INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone"] = "UIInterfaceOrientationPortrait"
  config.build_settings["GENERATE_INFOPLIST_FILE"] = "YES"
  config.build_settings["CURRENT_PROJECT_VERSION"] = "1"
  config.build_settings["MARKETING_VERSION"] = "1.0"
  config.build_settings["TARGETED_DEVICE_FAMILY"] = "1"
  config.build_settings["INFOPLIST_KEY_UIRequiresFullScreen"] = "YES"
  config.build_settings["INFOPLIST_KEY_UILaunchScreen_Generation"] = "YES"
  config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
  config.build_settings["DEVELOPMENT_TEAM"] = ""
end

%w[
  QuickLedgerApp.swift
  Models.swift
  AppServices.swift
  LedgerStore.swift
  AppShortcuts.swift
  ContentView.swift
].each do |file_name|
  file_ref = app_group.new_file(file_name)
  target.add_file_references([file_ref])
end

project.save

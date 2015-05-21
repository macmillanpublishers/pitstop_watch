require_relative '../bookmaker/header.rb'

# Add a notice to the conversion dir warning that the process is in use
File.open("#{Bkmkr::Paths.alert}", 'w') do |output|
	output.write "The conversion processor is currently running. Please do not submit any new files or images until the process completes."
end
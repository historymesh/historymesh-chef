from_file("#{ENV['HOME']}/.chef/knife.rb")

# Just a variable, not a config setting
current_dir = File.dirname(__FILE__)

cookbook_path            ["#{current_dir}/../cookbooks"]
chef_server_url          "https://api.opscode.com/organizations/historymesh"

validation_client_name   "historymesh-validator"
validation_key           "#{current_dir}/historymesh-validator.pem"

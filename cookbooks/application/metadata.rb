maintainer       "Opscode, Inc."
maintainer_email "cookbooks@opscode.com"
license          "Apache 2.0"
description      "Deploys and configures a variety of applications defined from databag 'apps'"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.99.14"
recipe           "application", "Loads application databags and selects recipes to use"
recipe           "application::django", "Deploys a Django application specified in a data bag with the deploy_revision resource"
recipe           "application::gunicorn", "Sets up the deployed Django application with Gunicorn as the web server"

%w{ gunicorn nginx }.each do |cb|
  depends cb
end

depends "python", ">= 1.0.6"

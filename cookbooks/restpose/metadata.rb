maintainer        "Ash Berlin"
maintainer_email "ash_github@firemirror.com"
license           "Apache 2.0"
description       "Installs and configures restpose search server"
version           "1.0.0"
recipe            "restpose::server", "Installs restpose from source"

depends "apt"
depends "build-essential"

name 'amazon-ecs-agent'
maintainer 'Will Salt'
maintainer_email 'williamejsalt@gmail.com'
license 'Apache 2.0'
description 'Installs/Configures amazon-ecs-agent'
long_description 'Installs/Configures amazon-ecs-agent'
version '1.2.4'

supports 'ubuntu'

depends 'docker', '~> 2.9.5'
depends 'chef-sugar'
depends 'apt'

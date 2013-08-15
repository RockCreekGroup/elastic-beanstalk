# ElasticBeanstalk

Configure and deploy a rails app to Elastic Beanstalk via rake in 60 seconds.  Maintain multiple environment DRY configurations and .ebextensions in one easy to use configuration file.

This gem simplifies configuration, and passes the heavy lifting to the [eb_deployer](https://github.com/ThoughtWorksStudios/eb_deployer) from ThoughtWorksStudios.

## Installation

Add this line to your application's Gemfile:

    gem 'elastic-beanstalk'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install elastic-beanstalk

## Usage

Given an application named 'acme':

### Step 1: Add a ~/.aws.acme.yml
This should contain the access and secret keys generated from the selected IAM user.  This is the only file that will need to reside outside the repository.

    access_key_id: XXXXXX
    secret_access_key: XXXXXX

### Step 2.  Add a config/eb.yml to your rails project
Something like this should get you started

    app: acme
    region: us-east-1
    solution_stack_name: 64bit Amazon Linux running Ruby 1.9.3

    development:
      strategy: inplace_update
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.micro

    production:
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.small

### Step 3. Package and deploy
The default is the 'development' environment, change this via command line by prefixing with i.e. RAILS_ENV=production

    $ rake eb:package eb:deploy

### Step 4. Get some coffee
This will take a while.  We intend to provide an example in the wiki and/or samples dir that implements a [caching strategy detailed here](http://horewi.cz/faster-rails-3-deployments-to-aws-elastic-beanstalk.html) to speed up deployment.

## Rake Tasks

    eb:config       # Setup AWS.config and merge/override environments into one resolved configuration.
    eb:show_config  # Show resolved configuration without doing anything. arguments[:version]
    eb:clobber      # Remove any generated package.
    eb:package      # Package zip source bundle for Elastic Beanstalk.
    eb:deploy       # Deploy to Elastic Beanstalk. arguments[:version]
    eb:destroy      # ** Warning: Destroy Elastic Beanstalk application and *all* environments. arguments[:force]

## A real-world example

Deploy version 1.1.3 of acme to production

    $ RAILS_ENV=production rake eb:package eb:deploy[1.1.3]

config/eb.yml

    # This is a sample that has not been executed so it may not be exactly 100%, but is intended to show
    #   that access to full options_settings and .ebextensions is intended.
    #---
    app: acme
    region: us-east-1
    solution_stack_name: 64bit Amazon Linux running Ruby 1.9.3
    package:
      verbose: true
      exclude_dirs: [solr, features] # additional dirs that merge with default excludes
      exclude_files: [rspec.xml, README*, db/*.sqlite3]
    smoke_test: |
        lambda { |host|

          require 'eb_smoke_tester'

          EbSmokeTester.test_url("http://#{host}/ping", 600, 5, 'All good! Everything is up and checks out.')
        }
    #--
    ebextensions:
      01settings.config:
        # Run rake tasks before an application deployment
        container_commands:
          01seed:
            command: rake db:seed
            leader_only: true
      # run any necessary commands
      02commands.config:
        container_commands:
          01timezone:
            command: "ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime"
    #---
    options:
      aws:autoscaling:launchconfiguration:
        EC2KeyName: eb-ssh
        SecurityGroups: 'acme-production-control'

      aws:autoscaling:asg:
        MinSize: 1
        MaxSize: 5

      aws:elb:loadbalancer:
        SSLCertificateId: 'arn:aws:iam::XXXXXXX:server-certificate/acme'
        LoadBalancerHTTPSPort: 443

      aws:elb:policies:
        Stickiness Policy: true

      aws:elasticbeanstalk:sns:topics:
        Notification Endpoint: 'alerts@acme.com'

      aws:elasticbeanstalk:application:
        Application Healthcheck URL: '/'
    #---
    development:
      strategy: inplace_update
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.micro
        aws:elasticbeanstalk:application:environment:
          RAILS_SKIP_ASSET_COMPILATION: true
    #---
    production:
      options:
        aws:autoscaling:launchconfiguration:
          InstanceType: t1.small

## Still to come
1. RDS sample config
2. Caching sample config
3. More thorough access to the Elastic Beanstalk api as-needed.

## Contributing

Please contribute! While this is working great, a greater scope of functionality is certainly easily attainable with this foundation in place.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

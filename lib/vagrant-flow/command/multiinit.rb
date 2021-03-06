require "vagrant"
require 'optparse'
require "yaml"
require 'erubis'
require "ipaddr"

module VagrantPlugins
  module CommandVagrantFlow
    module Command
      class MultiInit < Vagrant.plugin("2", :command)
        
        # Builtin from Command class
        # Must override to provide a description
        def self.synopsis
          "Grabs a multitude of vagrant cloud boxes"
        end
        
        
        # Builtin from Command class
        # Must override to provide core functionality
        def execute
          default_group_config_file = "multiinitconfig.yml"
          options = {}
          options[:destroy_on_error] = true
          options[:parallel] = false
          options[:provision_ignore_sentinel] = false
          options[:quiet] = false
          
          #Default virtualbox__intnet name for private network
          options[:vboxintnet] = "neverwinterDP"
          
          #Setting to read in a file other than default_group_config_File
          options[:vagrant_cloud_config_file] = false
          
          #Parse option, look up OptionParser documentation 
          opts = OptionParser.new do |o|
            # o.banner = "Usage: vagrant ansible-inventory [vm-name] [options] [-h]"
            o.banner = "A NeverWinterDP technology from the Department of Badass.\n\n"+
                        "Usage: vagrant flow multiinit [-hgliq]\nThis looks for multiinit.yml as the default configuration\n"
            o.separator ""
            o.on("-g", "--vagrant_multiinit_config_file FILEPATH", "(Optional) YAML file containing vagrant cloud config") do |f|
              options[:vagrant_cloud_config_file] = f        
            end
            
            o.on( '-l', '--list hostname:cloud/location,hostname2:cloud/location2,hostname3:cloud/location3', Array, "List of cloud config parameters" ) do|f|
              options[:vagrant_cloud_list] = f
            end
            
            o.on("-i", "--vboxintnet NAME", "(Optional) Custom virtualbox__intnet name for private network") do |f|
              options[:vboxintnet] = f
            end
            
            o.on("-q", "--quiet", "(Optional) Suppress output to STDOUT and STDERR") do |f|
              options[:quiet] = true
            end
            
          end
  
          # Parse the options # Builtin from the Command Class
          # Will safely parse the arguments and 
          # Automatically detects -h for help
          argv = parse_options(opts)
          return if !argv
          
          
          #If no options are given, set the config file to the default
          #and continue on our merry way
          if not options[:vagrant_cloud_config_file] and not options[:vagrant_cloud_list]
            options[:vagrant_cloud_config_file] = default_group_config_file
          end
          
          #Get machine configs from config file or from command line
          content = {}
          if options[:vagrant_cloud_config_file]
            begin
              #Load YAML
              content = YAML.load_file(options[:vagrant_cloud_config_file])
            rescue
              #Give warning if no file could be found
              if not options[:quiet]
                warn "Could not open file: "+options[:vagrant_cloud_config_file].to_s
              end
            end
            
            #Set intnetName if its not in the config
            if not content.has_key?(:intnetName)
              content[:intnetName]=options[:vboxintnet]
            end
            
          end
          
          #Read in command line config
          if options[:vagrant_cloud_list]
            machines = []
            options[:vagrant_cloud_list].each {|item|
              split = item.split(":")
              machines.push({
                              "name"=>split[0],
                              "url"=>split[1],
                              })
            }
            content = {
              :intnetName=>options[:vboxintnet],
              "machines" => machines,
            }
          end
          
          #Bail out here if content is fubar
          if not content.has_key?("machines")
            return
          end
          
          #Set IP's for private network
          #Start at 192.168.1.0 and increment up
          #using the IPAddr class
          ip= IPAddr.new("192.168.1.0")
          content["machines"].each {|machine|
            ip = IPAddr.new(ip.to_s).succ
            
            #If IP ends in x.x.x.0 or x.x.x.1, keep going one more
            #to avoid conflicts with routers/gateways/etc
            if ip.to_s.split(//).last(2) == [".","0"]
              ip = IPAddr.new(ip.to_s).succ
            end
            if ip.to_s.split(//).last(2) == [".","1"]
              ip = IPAddr.new(ip.to_s).succ
            end
            machine["ip"] =   ip.to_s
          }
          
          
          #Put Vagrantfile in pwd
          save_path = Pathname.new("Vagrantfile").expand_path(@env.cwd)
          
          #Error out if Vagrantfile already exists
          raise Vagrant::Errors::VagrantfileExistsError if save_path.exist?
          
          #Get current directory, go up one directory, then append path to templates/cloudbox.erb
          template_path = File.join(File.expand_path("..",File.dirname(__FILE__)) , ("templates/multiinit.erb"))
          
          #Load template file and write contents
          eruby = Erubis::Eruby.new(File.read(template_path))
          begin
            save_path.open("w+") do |f|
              f.write(eruby.evaluate(content))
            end
          rescue Errno::EACCES
            raise Vagrant::Errors::VagrantfileWriteError
          end
          
        end
      end       
    end    
  end
end

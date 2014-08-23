require 'fileutils'
require 'certificate_authority'
require 'rubygems'

module CreateCA
  def write_cert(file, cert)
    File.open(file, 'w') do |phile|
      phile.write cert.to_pem
    end
  end

  def write_private(file, cert)
    File.open(file, 'w') do |phile|
      phile.write cert.key_material.private_key.to_pem
    end
  end

  def write_public(file, cert)
    File.open(file, 'w') do |phile|
      phile.write cert.key_material.public_key.to_pem
    end
  end
end

begin
  Gem::Deprecate.skip = true if defined?(Gem::Deprecate)
rescue LoadError => e
  p e
end

# Including the CreateCA module means you can call its methods directly,
# so CreateCA::write_public becomes simply write_public, etc.
include CreateCA
@sslroot = "src/secure/ssldata/files"
FileUtils::mkdir_p @sslroot

namespace :ca do
    task :init do
      FileUtils::mkdir_p "#{@sslroot}"

      File.open("ssl/serial", File::RDWR|File::CREAT, 0644) {|f|
        @serial = f.read.chomp.to_i + 1
      }

      # Generate root_cert CA using example code at https://github.com/cchandler/certificate_authority
      puts "Creating new root CA..."
      root_cert = CertificateAuthority::Certificate.new
      root_cert.subject.common_name= "Dummy CA Root Certificate"
      root_cert.serial_number.number=@serial
      @serial = @serial + 1
      root_cert.key_material.generate_key
      root_cert.signing_entity = true
      signing_profile = {"extensions" => {"keyUsage" => {"usage" => ["critical", "keyCertSign"] }} }
      root_cert.sign!(signing_profile)

      # Create an intermediate_cert CA
      puts "Creating new intermediate CA..."
      intermediate_cert = CertificateAuthority::Certificate.new
      intermediate_cert.subject.common_name= "Dummy Intermediate Certificate"
      intermediate_cert.serial_number.number=@serial
      @serial = @serial + 1
      intermediate_cert.key_material.generate_key
      intermediate_cert.signing_entity = true
      intermediate_cert.parent = root_cert
      signing_profile = {"extensions" => {"keyUsage" => {"usage" => ["critical", "keyCertSign"] }} }
      intermediate_cert.sign!(signing_profile)
      puts "Signed intermediate CA with root CA"

      File.open("#{@sslroot}/serial", File::RDWR|File::CREAT, 0644) {|f|
        f.write("#{@serial}\n")
      }

      cert_files = {
        root_cert => { cert:        "#{@sslroot}/root_ca.crt",
                      private_key: "#{@sslroot}/root_ca-private.key",
                      public_key:  "#{@sslroot}/root_ca-public.key"
                    },
        intermediate_cert => { cert:       "#{@sslroot}/intermediate_ca.crt",
                              private_key: "#{@sslroot}/intermediate_ca-private.key",
                              public_key:  "#{@sslroot}/intermediate_ca-public.key"
                            }
      }

      cert_files.each do |cert, files|
        write_cert(files[:cert], cert)
        write_private(files[:private_key], cert)
        write_public(files[:public_key], cert)
      end

      File.open("#{@sslroot}/ca-chain", "w") do |file|
        file.write root_cert.to_pem
        file.write intermediate_cert.to_pem
        puts "Created ca-chain as #{@sslroot}/ca-chain"
      end
    end
  desc 'Create an SSL certificate for a given FQDN'
    task :cert, :fqdn do |t, args|
      common_name = args[:fqdn].to_s.chomp

      Rake::Task["ca:init"].execute unless File.file?("#{@sslroot}/ca-chain")

      puts "Creating SSL certs for #{common_name}..."

      PWD = Pathname(__FILE__).dirname

      def sslfile(name)
        PWD.join('..', @sslroot, name)
      end

      @ca_pem = sslfile('intermediate_ca.crt').read
      @issuer = OpenSSL::X509::Certificate.new(@ca_pem)
      ca = CertificateAuthority::Certificate.from_openssl(@issuer)

      @ca_private_key = sslfile('intermediate_ca-private.key').read
      ca.key_material.private_key = OpenSSL::PKey::RSA.new(@ca_private_key)

      File.open("#{@sslroot}/serial", File::RDWR|File::CREAT, 0644) {|f|
        @serial = f.read.chomp.to_i + 1
      }

      plain_cert = CertificateAuthority::Certificate.new
      plain_cert.subject.common_name = common_name
      plain_cert.serial_number.number = @serial
      plain_cert.key_material.generate_key
      plain_cert.parent = ca
      plain_cert.sign!
      puts "Signed certificate for #{common_name} with intermediate CA"

      common_name.gsub!('*','wildcard') # avoid putting "*" in filenames
      File.open("#{@sslroot}/#{common_name}.crt", "w") do |file|
        file.write plain_cert.to_pem
        puts "Created #{@sslroot}/#{common_name}.crt"
      end
      File.open("#{@sslroot}/#{common_name}-private.key", "w") do |file|
        file.write plain_cert.key_material.private_key.to_pem
        puts "Created #{@sslroot}/#{common_name}-private.key"
      end
      File.open("#{@sslroot}/#{common_name}-public.key", "w") do |file|
        file.write plain_cert.key_material.public_key.to_pem
        puts "Created #{@sslroot}/#{common_name}-public.key"
      end

      ca_chain = File.read("ssl/ca-chain")
      File.open("#{@sslroot}/#{common_name}-chained.crt", "w") do |file|
        file.write plain_cert.to_pem
        file.write ca_chain
        puts "Created #{@sslroot}/#{common_name}-chained.crt"
      end

      File.open("ssl/serial", File::RDWR|File::CREAT, 0644) {|f|
        f.write("#{@serial}\n")
      }

    end
  desc 'Add CA certs to trust root on a vagrant node'
    task :trust, :node do |t, args|
      node = args[:node]
      system "echo 'sudo cp /vagrant/#{@sslroot}/*ca.crt /usr/local/share/ca-certificates/ ; sudo /usr/sbin/update-ca-certificates' | vagrant ssh #{node}"
    end
end

#!/usr/bin/ruby

require 'rubygems'
require 'tlsmail'
require 'time'
# require 'parseconfig'

### Main script that handles the messages sent by the contact formular on the webpage. It gets four command line parameters, 
### -n name 
### -e email
### -s subject
### -m message (words connected by "__")

class SendMessage 

  def initialize(opts)
    @name =""
    @email =""
    @subject =""
    @message =""
    i = 0
    while i<opts.size
      if opts[i].eql?("-n")
        @name = opts[i+1]
        i = i+1
      elsif
        opts[i].eql?("-e")
        @email = opts[i+1]
        i = i+1
      elsif
        opts[i].eql?("-s")
        @subject = opts[i+1]
        i = i+1
      elsif opts[i].eql?("-m")
        @message = opts[i+1]
        i = i+1
      end
      i = i+1
    end
    if @name.eql?("")
      @name = "NONAME"
    else
      @name = @name.gsub(/\_\_/," ")
    end
    if @email.eql?("")
      @email = "NOEMAIL"
    end

    if @subject.eql?("")
      @subject= "Contact message from webserver with no subject."
    else
      @subject = @subject.gsub(/\_\_/," ")
    end
    @message = @message.gsub(/\_\_/," ")
    @message =  @message.gsub(/\#n\#/,"\n")
    send_email
    
  end  

  
  def send_email
    config_lines = File.open( File.join( RAILS_ROOT, "lib", "email.conf"), "r").readlines.map{ |line| line.chop }
    from = config_lines[0]
    password = config_lines[1]
    

#     email_config = ParseConfig.new("#{RAILS_ROOT}/lib/email.conf").params
#     email_config = ParseConfig.new('/home/aberer/proj/srv/websrv/lib/email.conf').params
#     from = email_config['from_address']
    to = ["andre.aberer@googlemail.com"]
#     password = email_config['password']
    
    to.each do | to_addr |
      content =   <<EOF
From: #{from}
To: #{to_addr}
subject: #{@subject}
Date: #{Time.now.rfc2822}


\"#{@name}\" with email address #{@email} just sent you a message. The content is: 
#{@message}


EOF
      
      Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)  
      Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', from, password, :login) do |smtp| 
        smtp.send_message(content, from, to)
      end
    end
  end    
end

SendMessage.new(ARGV)

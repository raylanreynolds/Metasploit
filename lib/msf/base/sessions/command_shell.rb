require 'msf/base'

module Msf
module Sessions

###
#
# This class provides basic interaction with a command shell on the remote
# endpoint.  This session is initialized with a stream that will be used
# as the pipe for reading and writing the command shell.
#
###
class CommandShell

	#
	# This interface supports basic interaction.
	#
	include Msf::Session::Basic

	#
	# This interface supports interacting with a single command shell.
	#
	include Msf::Session::Provider::SingleCommandShell

	#
	# Returns the type of session.
	#
	def self.type
		"shell"
	end

	#
	# Find out of the script exists (and if so, which path)
	#
	ScriptBase     = Msf::Config.script_directory + Msf::Config::FileSep + "shell"
	UserScriptBase = Msf::Config.user_script_directory + Msf::Config::FileSep + "shell"

	def self.find_script_path(script)
		# Find the full file path of the specified argument
		check_paths =
			[
				script,
				ScriptBase + Msf::Config::FileSep + "#{script}",
				ScriptBase + Msf::Config::FileSep + "#{script}.rb",
				UserScriptBase + Msf::Config::FileSep + "#{script}",
				UserScriptBase + Msf::Config::FileSep + "#{script}.rb"
			]

		full_path = nil

		# Scan all of the path combinations
		check_paths.each { |path|
			if ::File.exists?(path)
				full_path = path
				break
			end
		}

		full_path
	end


	#
	# Returns the session description.
	#
	def desc
		"Command shell"
	end

	#
	# Explicitly runs a command.
	#
	def run_cmd(cmd)
		shell_command(cmd)
	end

	#
	# Calls the class method.
	#
	def type
		self.class.type
	end

	#
	# The shell will have been initialized by default.
	#
	def shell_init
		return true
	end

	#
	# Executes the supplied script.
	#
	def execute_script(script, args)
		full_path = self.class.find_script_path(script)

		# No path found?  Weak.
		if full_path.nil?
			print_error("The specified script could not be found: #{script}")
			return true
		end

		o = Rex::Script::Shell.new(self, full_path)
		o.run(args)
	end


	#
	# Explicitly run a single command, return the output.
	#
	def shell_command(cmd)
		# Send the command to the session's stdin.
		shell_write(cmd + "\n")

		# wait up to 5 seconds for some data to appear
		elapsed = 0
		if (not (select([rstream], nil, nil, 5)))
			return nil
		end

		# get the output that we have ready
		rstream.get_once(-1, 1)
	end


	#
	# Read data until we find the token
	#
	def shell_read_until_token(token)
		# wait up to 5 seconds for some data to appear
		elapsed = 0
		if (not (select([rstream], nil, nil, 5)))
			return nil
		end

		# Read until we get the token or timeout.
		buf = ''
		idx = nil
		while (tmp = rstream.get_once(-1, 1))
			buf << tmp
			break if (idx = buf.index(token))
		end

		if (buf and idx)
			data = buf.slice(0,idx)
			return data
		end

		# failed to get any data or find the token!
		nil
	end

	#
	# Explicitly run a single command and return the output.
	# This version uses a marker to denote the end of data (instead of a timeout).
	#
	def shell_command_token_unix(cmd)
		# read any pending data
		buf = rstream.get_once(-1, 0.01)
		token = ::Rex::Text.rand_text_alpha(32)

		# Send the command to the session's stdin.
		shell_write(cmd + ";echo #{token}\n")
		shell_read_until_token(token)
	end

	#
	# Explicitly run a single command and return the output.
	# This version uses a marker to denote the end of data (instead of a timeout).
	#
	def shell_command_token_win32(cmd)
		# read any pending data
		buf = rstream.get_once(-1, 0.01)
		token = ::Rex::Text.rand_text_alpha(32)

		# Send the command to the session's stdin.
		shell_write(cmd + "&echo #{token}\n")
		shell_read_until_token(token)
	end


	#
	# Read from the command shell.
	#
	def shell_read(length = nil)
		if length.nil?
			rv = rstream.get_once(-1, 0)
		else
			rv = rstream.read(length)
		end
		return rv
	end

	#
	# Writes to the command shell.
	#
	def shell_write(buf)
		rstream.write(buf)
	end

	#
	# Closes the shell.
	#
	def shell_close()
		rstream.close
	end

end

end
end

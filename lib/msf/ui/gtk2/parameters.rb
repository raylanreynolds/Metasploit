module Msf
module Ui
module Gtk2

##
# Skeleton class for all parameters stuff
# title = Options title (menu)
# items = Array
##
class SkeletonOption < Gtk::Dialog
	
	attr_accessor :frame
	
	def initialize(title, items)
		super("", $gtk2driver.main, Gtk::Dialog::DESTROY_WITH_PARENT,
			[ Gtk::Stock::OK, Gtk::Dialog::RESPONSE_NONE ],
			[ Gtk::Stock::CLOSE, Gtk::Dialog::RESPONSE_NONE ])
		
		self.border_width = 6
		self.resizable = true
		self.has_separator = true
		self.vbox.spacing = 12
		self.vbox.set_homogeneous(false)
		self.title = title
		self.set_default_size(500, 400)
		
		model = create_model(items)
		treeview = Gtk::TreeView.new(model)
		treeview.set_size_request(5, 200)
		
		@hbox = Gtk::HBox.new(false, 10)
		
		# ScrolledWindow
		sw = Gtk::ScrolledWindow.new
		sw.set_policy(Gtk::POLICY_NEVER, Gtk::POLICY_AUTOMATIC)
		@hbox.pack_start(sw)
		sw.add(treeview)
		
		renderer = Gtk::CellRendererText.new
		column = Gtk::TreeViewColumn.new('Select an item', renderer, 'text' => 0)
		#column.fixed_width = 20
		column.pack_start(renderer, false)
		treeview.append_column(column)
		
		self.vbox.pack_start(@hbox, false, false, 0)
		@frame = Gtk::Frame.new
		@frame.set_size_request(300, 400)
		@hbox.pack_end(@frame, true, true, 0)
		
		# Signal
		selection = treeview.selection
		selection.mode = Gtk::SELECTION_SINGLE
		selection.signal_connect('changed') do |s|
			selection_changed(s)
		end
	end
	
	#
	# Create and return the model
	#
	def create_model(items)
		store = Gtk::ListStore.new(String)
		
		items.each do |item|
			iter = store.append
			iter[0] = item
		end
		
		return store
	end
	
	#
	# Destroy all children widgets in the frame
	#
	def clean_frame
		@frame.each do |w|
			w.destroy
		end
	end
	
	#
	# Dummy 
	#
	def selection_changed(selection)
		#
		# must be present in the real class
		#
	end
	
	#
	# Return a dialog file chooser
	#
	def file_chooser(title=nil)
		dialog = Gtk::FileChooserDialog.new(title, 
							nil,
							Gtk::FileChooser::ACTION_OPEN,
							nil,
							[Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT],
							[Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL]
							)
	end
end

class MsfParameters
	##
	# Display the preference parameters
	##
	class Preferences < Msf::Ui::Gtk2::SkeletonOption
		def initialize
			menu = ["Exploits", "Payloads"]
			super("Preferences", menu)
			
			w_exploits
			
			show_all and run
			destroy
		end
		
		#
		# Describe the exploits widget
		#
		def w_exploits
			frame.set_label("Exploits")
			frame.add(Gtk::Label.new("Add specifics widgets here"))
			frame.show_all
		end
		
		#
		# Describe the payloads widget
		#
		def w_payloads
			frame.set_label("Payloads")
			frame.shadow_type = Gtk::SHADOW_IN
			#frame.add(Gtk::Label.new("Add specifics widgets here"))
			
			#
			# add specific widget here
			#
			vbox_frame = Gtk::VBox.new(false, 0)
			
			# VNC			
			frame.add(vbox_frame)
			
			table_vnc = Gtk::Table.new(2, 2, false)
			table_vnc.set_row_spacings(4)
			table_vnc.set_column_spacings(4)
			vbox_frame.pack_start(table_vnc, false, false, 5)
			
			label_vnc = Gtk::Label.new("Viewer VNC path: ")
			table_vnc.attach_defaults(label_vnc, 0, 1, 0, 1)
			
			hbox_vnc = Gtk::HBox.new(false, 5)			
			entry_vnc = Gtk::Entry.new
			table_vnc.attach_defaults(entry_vnc, 0, 2, 1, 2)
			
			button_vnc = Gtk::HButtonBox.new
			button_vnc.layout_style = Gtk::ButtonBox::END
			button = Gtk::Button.new(Gtk::Stock::OPEN)
			button_vnc.add(button)
			#button_vnc = Gtk::FileChooserButton.new("Select a file", Gtk::FileChooser::ACTION_OPEN)
			table_vnc.attach_defaults(button_vnc, 1, 2, 0, 1)
			button.signal_connect('clicked') do
				dialog = file_chooser("Select your VNC viewer")
				if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
					entry_vnc.set_text(dialog.uri)
				end
				dialog.destroy
			end
			
			frame.show_all
		end
		
		#
		# Signals
		#
		def selection_changed(selection)
			iter = selection.selected
			case iter[0]
				when "Exploits"
					clean_frame and w_exploits
				when "Payloads"
					clean_frame and w_payloads
			end
		end
	end
	
	
	##
	# Display the databases parameters
	##
	class Databases < Msf::Ui::Gtk2::SkeletonOption
		def initialize
			menu = ["AutoPOWN", "OPCODES"]
			super("Databases", menu)
			
			show_all and run
			destroy
		end
		
		#
		# Describe the autopown widget
		#
		def w_autopown
			frame.set_label("AutoPWN")
		end
		
		#
		# Describe the opcode widget opcodes
		#
		def w_opcode
			frame.set_label("OPCODES")
		end
		
		#
		# Signals
		#
		def selection_changed(selection)
			iter = selection.selected
			case iter[0]
				when "AutoPOWN"
					clean_frame and w_autopown
				when "OPCODES"
					clean_frame and w_opcode
			end
		end
	end
	
	###
	# Display the options parameters
	###
	class Options < Msf::Ui::Gtk2::SkeletonOption
		def initialize
			menu = ["Debug", "Tips", "Proxy", "Update"]
			super("Options", menu)
			
			show_all and run
			destroy
		end
		
		def w_debug
			frame.set_label("Debug")
		end
		
		#
		# Want to show tips ... or not !
		#
		def w_tips
			frame.set_label("Tips")
		end
		
		#
		# Need a proxy ?
		#
		def w_proxy
			frame.set_label("Proxy")
		end
		
		#
		# Update stuff
		#
		def w_update
			frame.set_label("Update")
		end
		
		#
		# Signals
		#
		def selection_changed(selection)
			iter = selection.selected
			case iter[0]
				when "Debug"
					clean_frame and w_debug
				when "Tips"
					clean_frame and w_tips
				when "Proxy"
					clean_frame and w_proxy
				when "Update"
					clean_frame and w_update
			end
		end
	end
end

end
end
end

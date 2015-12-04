class Makeconf::GUI

  def initialize(project)
    require 'tk'

    @project = project
    @page = [ 'intro_page', 
              'license_page',
# TODO:'install_prefix_page',
              'build_page',
              'outro_page',
         ]
    @pageIndex = 0

    @mainTitle = TkVariable.new 
    @mainMessage = TkVariable.new 

    @root = TkRoot.new() { 
        title "Installation" 
    }

    @mainTitleWidget = TkLabel.new(@root) {
        pack('side' => 'top')
    }
    @mainTitleWidget.configure('textvariable', @mainTitle)

    @mainFrame = TkFrame.new(@root) {
        height      600
        width       600
        background  'white'
        borderwidth 5
        relief      'groove'
        padx        10
        pady        10
        pack('side' => 'top')
    }

    @mainLabel = TkLabel.new(@mainFrame) {
        background  'white'
    }
    @mainLabel.configure('textvariable', @mainMessage)
    
    @mainText = TkText.new(@mainFrame) {
        background  'white'
    }

    @cancelButton = TkButton.new(@root) { 
        text "Cancel" 
        command proc {
            exit 1
        }
        pack('side' => 'left')
    }

    @nextButton = TkButton.new(@root) { 
        text "Next" 
        pack('side' => 'right')
    }
    @nextButton.configure('command', method(:next_page))
#nextButton.configure('command', proc { mainMessage.set_value 'You click it' })
    @nextButtonEnable = true

    @backButton = TkButton.new(@root) { 
        text    "Back" 
        command proc { prev_page }
        state   'disabled'
        pack('side' => 'right')
    }
    @backButton.configure('command', method(:prev_page))
    @backButtonEnable = true

    update_buttons
  end

  def next_page
    eval "#{@page[@pageIndex]}(false)"
    @pageIndex = @pageIndex + 1
    eval "#{@page[@pageIndex]}(true)"
    update_buttons
  end

  def prev_page
    eval "#{@page[@pageIndex]}(false)"
    @pageIndex = @pageIndex - 1
    eval "#{@page[@pageIndex]}(true)"
    update_buttons
  end

  # Update the Back and Next buttons based on the position in the pagelist
  def update_buttons
    if @pageIndex == 0
      @backButton.configure('state', 'disabled')
      @nextButton.configure('state', 'normal')
      @nextButton.configure('text', 'Next')
    elsif @pageIndex == @page.length - 1
      @nextButton.configure('text', 'Finish')
      @nextButton.configure('command', proc { exit 0 })
      @backButton.configure('state', 'disabled')
      @cancelButton.configure('state', 'disabled')
    else
      @nextButton.configure('text', 'Next')
      @nextButton.configure('state', @nextButtonEnable ? 'normal' : 'disabled')
      @backButton.configure('state', @backButtonEnable ? 'normal' : 'disabled')
    end
  end

  def main_loop
    eval "#{@page[0]}(true)"
    Tk.mainloop()
  end

  def intro_page(display)
    if display
      @mainTitle.set_value 'Welcome'
      @mainLabel.place('relx'=>0.0, 'rely' => 0.0)
      @mainMessage.set_value "This will install #{@project.id} on your computer"
    else
      TkPlace.forget(@mainLabel)
    end
  end

  def license_page(display)
    if @project.license_file.nil?
      license = 'No license information'
    else
      license = File.read(@project.license_file)
    end

    if display
      @mainTitle.set_value 'License Agreement'
      @mainText.insert('end', license)
      @mainText.place('relx'=>0.0, 'rely' => 0.0)
    else
      TkPlace.forget(@mainText)
      @mainText.delete(1.0, 'end')
    end
  end

  def install_prefix_page(display)
    if display
      @mainTitle.set_value 'Installation Path'
      @mainText.insert('end', "choose an installation path")
      @mainText.place('relx'=>0.0, 'rely' => 0.0)
      Tk.getOpenFile
    else
      TkPlace.forget(@mainText)
      @mainText.delete(1.0, 'end')
    end
  end

  def build_page(display)
    if display
      @nextButtonEnable = false
      update_buttons
      @mainTitle.set_value 'Checking Configuration'
      @mainText.delete(1.0, 'end')
      @mainText.place('relx'=>0.0, 'rely' => 0.0)
      Thread.new {
          @mainText.insert('end', "Configuring.. ")
          Makeconf.configure_project(@project)
          @mainText.insert('end', "done\n")

          make = Platform.is_windows? ? 'nmake' : 'make'

          @mainText.insert('end', "Building.. ")
          system "#{make}"
          @mainText.insert('end', "done\n")

          @mainText.insert('end', "Installing.. ")
          system "#{make} install"
          @mainText.insert('end', "done\n")

          @mainText.insert('end', "\nAll tasks completed.")

          @nextButtonEnable = true
          update_buttons
      }
    else
      TkPlace.forget(@mainText)
      @mainText.delete(1.0, 'end')
    end
  end

  def outro_page(display)
    if display
      @mainTitle.set_value 'Installation Complete'
      @mainLabel.place('relx'=>0.0, 'rely' => 0.0)
      @mainMessage.set_value "Installation is complete."
    else
      TkPlace.forget(@mainLabel)
    end
  end

end

__END__
# UNUSED: might use for showing error messages if "require 'tk'" fails
#
class Makeconf::GUI::Minimal

  if Platform.is_windows?
    require 'dl'
  end

  def initialize
  end

  # Display a graphical message box
  def message_box(txt, title, buttons=0)
    if Platform.is_windows?

# FIXME: add conditional

#Ruby 1.8:
#      user32 = DL.dlopen('user32')
#      msgbox = user32['MessageBoxA', 'ILSSI']
#      r, rs = msgbox.call(0, txt, title, buttons)
#      return r

#Ruby 1.9:
    user32 = DL.dlopen('user32')
    msgbox = DL::CFunc.new(user32['MessageBoxA'], DL::TYPE_LONG, 'MessageBox')
    r, rs = msgbox.call([0, txt, title, buttons].pack('L!ppL!').unpack('L!*'))
    return r
    elsif Platform.is_linux?
      #XXX-scrub txt to eliminate "'" character
      cmd = "zenity --text='#{txt}' " + (buttons > 0 ? '--question' : '--info')
      rv = system cmd
      return rv == true ? 1 : 0
    else
      throw 'STUB'
    end
  end

  # Display an informational message with a single 'OK' button
  def notice(txt, title)
    message_box(txt, title, 0)
  end

  # Display an confirmation message with an OK button and CANCEL button
  def confirm(txt, title)
    return (message_box(txt, title, 1) == 1) ? true : false
  end

end

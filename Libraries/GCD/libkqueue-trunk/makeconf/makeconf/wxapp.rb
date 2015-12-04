class Makeconf::WxApp < Wx::App

  require 'rubygems'
  require 'wx'

  def on_init
    @frame = Wx::Frame.new(nil, -1, 'Testing')
    @wizard = Wx::Wizard.new(@frame)
    pages = [
        welcome
        ]
    @wizard.run_wizard(pages[0])
    @wizard.Destroy()
  end   

  def welcome
    x = Wx::WizardPageSimple.new(@wizard)
    Wx::StaticText.new(@wizard, :label => 'testing')
    x
  end

end

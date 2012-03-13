namespace Boo.MonoDevelop.ProjectModel.GUI

import MonoDevelop.Projects
import MonoDevelop.Ide.Gui.Dialogs

import Boo.MonoDevelop.ProjectModel
import Gtk from "gtk-sharp"
	
class BooCompilationParametersPanel(MultiConfigItemOptionsPanel):
	
	override def CreatePanelWidget():
		vbox = VBox ()
		definesHbox = HBox ()
		_noStdLibCheckButton = CheckButton.NewWithLabel("No standard libraries")
		vbox.PackStart (_noStdLibCheckButton, false, true, 5)
		_definesEntry = Entry ()
		definesLabel = Label ("Define Symbols: ")
		definesHbox.PackStart (definesLabel, false, false, 5)
		definesHbox.PackStart (_definesEntry, true , true, 5)
		vbox.PackStart (definesHbox, true, true, 5)
		vbox.ShowAll ()
		return vbox
	
	override def LoadConfigData():
		_noStdLibCheckButton.Active = BooCompilationParameters.NoStdLib
		_definesEntry.Text = BooCompilationParameters.DefineConstants
		
	override def ValidateChanges():
		return true
		
	override def ApplyChanges():
		BooCompilationParameters.NoStdLib = _noStdLibCheckButton.Active
		BooCompilationParameters.DefineConstants = _definesEntry.Text
		
	BooCompilationParameters as BooCompilationParameters:
		get:
			config as DotNetProjectConfiguration = self.CurrentConfiguration
			return config.CompilationParameters
		
	_noStdLibCheckButton as Gtk.CheckButton
	_definesEntry as Gtk.Entry
	
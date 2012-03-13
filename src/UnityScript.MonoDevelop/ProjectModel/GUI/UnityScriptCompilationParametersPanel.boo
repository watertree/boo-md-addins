namespace UnityScript.MonoDevelop.ProjectModel.GUI

import MonoDevelop.Projects
import MonoDevelop.Ide.Gui.Dialogs

import UnityScript.MonoDevelop.ProjectModel
import Gtk from "gtk-sharp"
	
class UnityScriptCompilationParametersPanel(MultiConfigItemOptionsPanel):
	
	override def CreatePanelWidget():
		vbox = VBox ()
		definesHbox = HBox ()
		_definesEntry = Entry ()
		definesLabel = Label ("Define Symbols: ")
		definesHbox.PackStart (definesLabel, false, false, 5)
		definesHbox.PackStart (_definesEntry, true , true, 5)
		vbox.PackStart (definesHbox, true, true, 5)
		vbox.ShowAll ()
		return vbox
	
	override def LoadConfigData():
		_definesEntry.Text = UnityScriptCompilationParameters.DefineConstants
		
	override def ValidateChanges():
		return true
		
	override def ApplyChanges():
		UnityScriptCompilationParameters.DefineConstants = _definesEntry.Text
		
	UnityScriptCompilationParameters as UnityScriptCompilationParameters:
		get:
			config as DotNetProjectConfiguration = self.CurrentConfiguration
			return config.CompilationParameters
		
	_definesEntry as Gtk.Entry
	
namespace Boo.MonoDevelop.ProjectModel.GUI

import MonoDevelop.Projects
import MonoDevelop.Ide.Gui.Dialogs

import Boo.MonoDevelop.ProjectModel
	
class BooCompilationParametersPanel(MultiConfigItemOptionsPanel):
	
	override def CreatePanelWidget():
		_noStdLibCheckButton = Gtk.CheckButton.NewWithLabel("No standard libraries")
		_noStdLibCheckButton.ShowAll()
		return _noStdLibCheckButton
	
	override def LoadConfigData():
		_noStdLibCheckButton.Active = BooCompilationParameters.NoStdLib
		
	override def ValidateChanges():
		return true
		
	override def ApplyChanges():
		BooCompilationParameters.NoStdLib = _noStdLibCheckButton.Active
		
	BooCompilationParameters as BooCompilationParameters:
		get:
			config as DotNetProjectConfiguration = self.CurrentConfiguration
			return config.CompilationParameters
		
	_noStdLibCheckButton as Gtk.CheckButton
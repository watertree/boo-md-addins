namespace Boo.MonoDevelop.ProjectModel

import MonoDevelop.Projects
import MonoDevelop.Core.Serialization

import Boo.MonoDevelop.Util

class BooCompilationParameters(ConfigurationParameters):
	
	ConfigurationItemProperty GenWarnings = false
	ConfigurationItemProperty Ducky = false
	ConfigurationItemProperty Culture = ""
	ConfigurationItemProperty NoStdLib = false
	
	override def AddDefineSymbol (symbol as string):
		# TODO: Implement
		pass
		
	override def RemoveDefineSymbol (symbol as string):
		# TODO: Implement
		pass
namespace Boo.MonoDevelop.ProjectModel

import MonoDevelop.Projects
import MonoDevelop.Core.Serialization

import Boo.MonoDevelop.Util

class BooCompilationParameters(ConfigurationParameters):
	
	ConfigurationItemProperty GenWarnings = false
	ConfigurationItemProperty Ducky = false
	ConfigurationItemProperty Culture = ""
	ConfigurationItemProperty NoStdLib = false
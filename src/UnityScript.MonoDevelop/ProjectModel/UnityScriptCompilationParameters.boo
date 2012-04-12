namespace UnityScript.MonoDevelop.ProjectModel

import System
import MonoDevelop.Projects
import MonoDevelop.Core.Serialization

class UnityScriptCompilationParameters(ConfigurationParameters):
	static DefineSeparator = ";"
	
	[ItemProperty]
	DefineConstants as string:
		get: return string.Join (DefineSeparator, _defines.ToArray ())
		set:
			if (string.IsNullOrEmpty (value)):
				_defines = System.Collections.Generic.List of string()
			else:
				_defines = System.Collections.Generic.List of string(value.Split ((DefineSeparator,), StringSplitOptions.RemoveEmptyEntries))
	private _defines = System.Collections.Generic.List of string()
	
	DefineSymbols:
		get: return _defines
	
	override def AddDefineSymbol (symbol as string):
		_defines.Add (symbol) unless _defines.Contains (symbol)
		
	override def RemoveDefineSymbol (symbol as string):
		_defines.Remove (symbol) if _defines.Contains (symbol)

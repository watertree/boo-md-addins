namespace Boo.MonoDevelop.Util.Completion

import System
import MonoDevelop.Ide.CodeCompletion

class BooCompletionDataList(CompletionDataList, IMutableCompletionDataList):
	event Changed as EventHandler
	event Changing as EventHandler
	
	_isChanging as bool
	
	public IsChanging as bool:
		get: return _isChanging
		set: 
			wasChanging = _isChanging
			_isChanging = value
			if _isChanging and not wasChanging:
				OnChanging(self, null)
			elif wasChanging and not _isChanging:
				OnChanged(self, null)
				
	def BooCompletionDataList():
		AutoSelect = false
		
	def Dispose():
		pass

	protected virtual def OnChanging(sender, args as EventArgs):
		Changing(sender, args)

	protected virtual def OnChanged(sender, args as EventArgs):
		Changed(sender, args)
		
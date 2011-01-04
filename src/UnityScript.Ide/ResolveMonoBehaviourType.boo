namespace UnityScript.Ide

import UnityScript
import Boo.Lang.Compiler.Steps

import System.Linq.Enumerable

class ResolveMonoBehaviourType(AbstractCompilerStep):
	
	override def Run():
		unityScriptParameters = Parameters as UnityScriptCompilerParameters
		if unityScriptParameters.ScriptBaseType is not null:
			print "ScriptBaseType is already set"
			return
			
		type = FindReferencedType("UnityEngine.MonoBehaviour")
		unityScriptParameters.ScriptBaseType = type or object
			
	def FindReferencedType(typeName as string):
		for assemblyRef in Parameters.References.OfType[of Boo.Lang.Compiler.TypeSystem.Reflection.IAssemblyReference]():
			type = assemblyRef.Assembly.GetType(typeName)
			if type is not null:
				return type
